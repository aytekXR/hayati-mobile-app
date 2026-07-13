// Build size report — prints the iOS bundle size breakdown and fails CI when
// the uncompressed .app exceeds a pathology budget (ADR-022 Decision 4).
//
// `flutter build ios --release --analyze-size --code-size-directory=<dir>` emits
// a treemap of the built .app to $HOME/.flutter-devtools/ios-code-size-analysis_NN.json
// (the --code-size-directory only receives the raw snapshot.<arch>.json /
// trace.<arch>.json intermediates — the full bundle tree lands under
// .flutter-devtools; verified against flutter_tools build_ios.dart). Each node is
// `{n: name, value: <bytes>, children: [...]}` where a node's `value` is its
// subtree total, so the root `value` is the whole uncompressed .app.
//
// This tool sums the top-level children into a breakdown table, prints the total,
// and compares it to --max-mb. MB is decimal (1000*1000) to match flutter's own
// iOS size reporting (utils.dart getSizeAsPlatformMB) and Apple's convention.
//
// Usage:   dart tool/build_size_report.dart --max-mb <N> <dir-or-json>
// Example: dart tool/build_size_report.dart --max-mb 200 "$HOME/.flutter-devtools"
//
// The positional path is either the analysis JSON itself or a directory to search
// (the newest ios-code-size-analysis*.json wins; the raw snapshot./trace. files
// flutter drops in --code-size-directory are skipped).
//
// Exit codes: 0 = at/under budget (PASS), 1 = over budget (FAIL),
//             64 = usage/input error (bad args, or a missing/unparseable/empty
//             analysis JSON — "couldn't measure" must never read as green, the
//             coverage-gate 0/0 precedent).

import 'dart:convert';
import 'dart:io';

// EX_USAGE from sysexits.h: input/usage error, distinct from a real budget FAIL.
const int _exitUsage = 64;

// Decimal MB, matching flutter's iOS size reporting (1000*1000, not 1024*1024).
const int _bytesPerMb = 1000 * 1000;

void main(List<String> args) {
  int? maxMb;
  String? path;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--max-mb') {
      if (i + 1 >= args.length) {
        _usageError('--max-mb requires a value.');
        return;
      }
      maxMb = int.tryParse(args[++i]);
    } else if (arg.startsWith('--max-mb=')) {
      maxMb = int.tryParse(arg.substring('--max-mb='.length));
    } else if (arg.startsWith('-')) {
      _usageError('unknown option: $arg');
      return;
    } else if (path == null) {
      path = arg;
    } else {
      _usageError('unexpected extra argument: $arg');
      return;
    }
  }

  if (maxMb == null || maxMb <= 0) {
    _usageError('--max-mb must be a positive integer.');
    return;
  }
  if (path == null) {
    _usageError('missing path to the analysis JSON (or its directory).');
    return;
  }

  final file = _resolveAnalysisFile(path);
  if (file == null) {
    stderr.writeln(
      'build_size_report: no size-analysis JSON found at $path. A missing '
      'artifact cannot pass the budget — check that `flutter build ios '
      '--release --analyze-size` ran and wrote ios-code-size-analysis*.json.',
    );
    exitCode = _exitUsage;
    return;
  }

  final Object? decoded;
  try {
    decoded = json.decode(file.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('build_size_report: ${file.path} is not valid JSON: $e');
    exitCode = _exitUsage;
    return;
  } on IOException catch (e) {
    stderr.writeln('build_size_report: cannot read ${file.path}: $e');
    exitCode = _exitUsage;
    return;
  }

  if (decoded is! Map<String, Object?>) {
    stderr.writeln(
      'build_size_report: ${file.path} is not a size-analysis treemap object.',
    );
    exitCode = _exitUsage;
    return;
  }

  final total = _nodeBytes(decoded);
  if (total == null) {
    stderr.writeln(
      'build_size_report: ${file.path} has no size total (expected node keys '
      '`value`/`children`). A tree that cannot be measured cannot pass.',
    );
    exitCode = _exitUsage;
    return;
  }

  stdout.writeln('build_size_report: source ${file.path}');

  final children = decoded['children'];
  final rows = <MapEntry<String, int>>[];
  if (children is List) {
    for (final child in children) {
      if (child is Map<String, Object?>) {
        final bytes = _nodeBytes(child);
        if (bytes != null) {
          rows.add(MapEntry(child['n'] as String? ?? '(unnamed)', bytes));
        }
      }
    }
  }
  rows.sort((a, b) => b.value.compareTo(a.value));

  stdout.writeln('build_size_report: top-level breakdown (uncompressed):');
  for (final row in rows) {
    final pct = total == 0 ? 0.0 : 100 * row.value / total;
    stdout.writeln(
      '  ${_mb(row.value).padLeft(9)} MB  '
      '${pct.toStringAsFixed(1).padLeft(5)}%  ${row.key}',
    );
  }

  final maxBytes = maxMb * _bytesPerMb;
  stdout.writeln(
    'build_size_report: total ${_mb(total)} MB ($total bytes), '
    'budget $maxMb MB.',
  );

  if (total > maxBytes) {
    stderr.writeln(
      'build_size_report: FAIL — ${_mb(total)} MB exceeds the $maxMb MB budget.',
    );
    exitCode = 1;
  } else {
    stdout.writeln('build_size_report: PASS.');
  }
}

// A node's byte size is its `value` (flutter sets it to the subtree total on
// every node); fall back to summing children so a value-less parent still counts.
int? _nodeBytes(Map<String, Object?> node) {
  final value = node['value'];
  if (value is int) return value;
  final children = node['children'];
  if (children is List) {
    var sum = 0;
    var sawOne = false;
    for (final child in children) {
      if (child is Map<String, Object?>) {
        final bytes = _nodeBytes(child);
        if (bytes != null) {
          sum += bytes;
          sawOne = true;
        }
      }
    }
    if (sawOne) return sum;
  }
  return null;
}

String _mb(int bytes) => (bytes / _bytesPerMb).toStringAsFixed(2);

// Resolve the positional path to the analysis JSON. A file is used as-is; a
// directory is searched (recursively) for the newest ios-code-size-analysis*.json,
// skipping the raw snapshot./trace. intermediates flutter drops in a
// --code-size-directory. Returns null when nothing usable is found.
File? _resolveAnalysisFile(String path) {
  if (FileSystemEntity.isFileSync(path)) return File(path);
  if (!FileSystemEntity.isDirectorySync(path)) return null;

  final candidates = Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) {
        final name = f.uri.pathSegments.last;
        return !name.startsWith('snapshot.') && !name.startsWith('trace.');
      })
      .toList();
  if (candidates.isEmpty) return null;

  int mtime(File f) => f.statSync().modified.millisecondsSinceEpoch;
  bool preferred(File f) =>
      f.uri.pathSegments.last.contains('code-size-analysis');

  final ranked = candidates.where(preferred).toList();
  final pool = ranked.isNotEmpty ? ranked : candidates;
  pool.sort((a, b) => mtime(b).compareTo(mtime(a)));
  return pool.first;
}

void _usageError(String message) {
  stderr.writeln('build_size_report: $message');
  stderr.writeln(
    'usage: dart tool/build_size_report.dart --max-mb <N> <dir-or-json>',
  );
  exitCode = _exitUsage;
}
