// Store-metadata lint — fails CI when fastlane/metadata drifts from Apple's
// submission rules. A credential-free, dependency-free stand-in for
// `fastlane precheck` (ADR-020 Decision 6): pure dart:io, runnable in the
// ubuntu quality/preflight jobs before any `pub get`.
//
// Per allowlisted locale dir under fastlane/metadata it checks: the required
// files exist (name/subtitle/description/keywords + privacy_url/support_url);
// Apple char limits in Unicode code points (name/subtitle 30, keywords 100,
// promotional_text 170, description/release_notes 4000); single-line fields
// (name/subtitle/keywords + the URLs) carry no surrounding whitespace and no
// internal newline; keywords have no empty and no duplicate terms; no unknown
// .txt filename sits in a locale dir (a name `deliver` would silently ignore);
// and every locale dir on disk is in the allowlist (a misnamed `en` for
// `en-US` cannot sit unvalidated). Empty privacy_url/support_url files are a
// hard failure unless --allow-empty-urls demotes them to a loud, counted
// warning — the ratchet that stays open until the founder hosts a privacy
// policy (ADR-020 D5). marketing_url is optional: absent or empty is always
// fine; a non-empty value gets the same well-formedness checks.
//
// Usage:   dart tool/store_metadata_lint.dart [--allow-empty-urls] <locale>...
// Example: dart tool/store_metadata_lint.dart --allow-empty-urls tr en-US
//
// Exit codes: 0 = clean (PASS; warnings allowed under --allow-empty-urls),
//             1 = violations (FAIL), 64 = usage/input error (bad args, no
//             locale given, or a missing fastlane/metadata dir — a "couldn't
//             check" must not read as green).

import 'dart:io';

// EX_USAGE from sysexits.h: input/usage error, distinct from a real lint FAIL.
const int _exitUsage = 64;

const String _metadataSubpath = 'fastlane/metadata';

// Deliver's recognized per-locale filenames that this project ships. Anything
// else with a .txt extension in a locale dir is a typo deliver would silently
// ignore — a hard failure here, not a silent no-op.
const List<String> _requiredTextFields = [
  'name',
  'subtitle',
  'description',
  'keywords',
];
const List<String> _requiredUrlFields = ['privacy_url', 'support_url'];
const List<String> _optionalUrlFields = ['marketing_url'];
const List<String> _optionalTextFields = ['promotional_text', 'release_notes'];

// Apple char limits, in Unicode code points.
const Map<String, int> _limits = {
  'name': 30,
  'subtitle': 30,
  'keywords': 100,
  'promotional_text': 170,
  'description': 4000,
  'release_notes': 4000,
};

// Fields that must be a single line: no surrounding whitespace, no newline.
const Set<String> _singleLineFields = {
  'name',
  'subtitle',
  'keywords',
  'privacy_url',
  'support_url',
  'marketing_url',
};

void main(List<String> args) {
  exitCode = runStoreMetadataLint(args, out: stdout, err: stderr);
}

/// In-process entrypoint so the self-tests (`store_metadata_lint_test.dart`)
/// can drive the lint against a temp tree without spawning a VM per case.
/// [root] is the repo root; defaults to the current directory.
int runStoreMetadataLint(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  String root = '.',
}) {
  final knownFields = <String>{
    ..._requiredTextFields,
    ..._requiredUrlFields,
    ..._optionalUrlFields,
    ..._optionalTextFields,
  };
  final urlFields = <String>{..._requiredUrlFields, ..._optionalUrlFields};

  var allowEmptyUrls = false;
  final locales = <String>[];
  for (final arg in args) {
    if (arg == '--allow-empty-urls') {
      allowEmptyUrls = true;
    } else if (arg.startsWith('-')) {
      err.writeln('store_metadata_lint: unknown option: $arg');
      _usage(err);
      return _exitUsage;
    } else {
      locales.add(arg);
    }
  }

  if (locales.isEmpty) {
    err.writeln(
      'store_metadata_lint: no locale given — pass at least one locale dir to '
      'validate (e.g. tr en-US).',
    );
    _usage(err);
    return _exitUsage;
  }

  final allowlist = <String>{};
  for (final loc in locales) {
    if (!allowlist.add(loc)) {
      err.writeln('store_metadata_lint: locale "$loc" listed twice.');
      _usage(err);
      return _exitUsage;
    }
  }

  final metadataDir = Directory('$root/$_metadataSubpath');
  if (!metadataDir.existsSync()) {
    err.writeln(
      'store_metadata_lint: metadata dir not found: $root/$_metadataSubpath — '
      'run from the repo root.',
    );
    return _exitUsage;
  }

  final violations = <String>[];
  final warnings = <String>[];

  // Every locale dir ON DISK must be in the allowlist — a misnamed dir (e.g.
  // `en` for `en-US`) must not sit unvalidated (ADR-020 D6).
  for (final entity in metadataDir.listSync().whereType<Directory>()) {
    final name = _baseName(entity.path);
    if (!allowlist.contains(name)) {
      violations.add(
        '$_metadataSubpath/$name: locale dir is not in the allowlist '
        '(${locales.join(', ')}) — add it to the lint invocation or remove '
        'the dir.',
      );
    }
  }

  for (final locale in locales) {
    final dir = Directory('$root/$_metadataSubpath/$locale');
    if (!dir.existsSync()) {
      violations.add('$_metadataSubpath/$locale: locale dir is missing.');
      continue;
    }

    // Which recognized fields are present; unknown .txt files are a hard fail.
    final present = <String>{};
    for (final file in dir.listSync().whereType<File>()) {
      final base = _baseName(file.path);
      if (!base.endsWith('.txt')) continue;
      final stem = base.substring(0, base.length - '.txt'.length);
      if (!knownFields.contains(stem)) {
        violations.add(
          '$_metadataSubpath/$locale/$base: unknown metadata file — deliver '
          'silently ignores unrecognized names; remove it or fix the typo.',
        );
        continue;
      }
      present.add(stem);
    }

    // Required files must exist.
    for (final field in [..._requiredTextFields, ..._requiredUrlFields]) {
      if (!present.contains(field)) {
        violations.add(
          '$_metadataSubpath/$locale: required file $field.txt is missing.',
        );
      }
    }

    // Per-field content checks, in a stable order.
    for (final stem in present.toList()..sort()) {
      final where = '$_metadataSubpath/$locale/$stem.txt';
      final content = File('$root/$where').readAsStringSync();

      // URL fields: empty-handling takes precedence over the single-line
      // checks (a whitespace-only URL file is "empty", not a whitespace bug).
      if (urlFields.contains(stem)) {
        if (content.trim().isEmpty) {
          if (_requiredUrlFields.contains(stem)) {
            if (allowEmptyUrls) {
              warnings.add(
                '$where: empty URL (accepted by --allow-empty-urls; the '
                'ratchet stays open until a hosted URL lands — ADR-020 D5).',
              );
            } else {
              violations.add(
                '$where: empty URL — Apple requires a reachable $stem at '
                'submission. Pass --allow-empty-urls to accept the honest gap '
                'pre-launch (ADR-020 D5).',
              );
            }
          }
          // Optional URL (marketing_url) empty/absent is always fine.
          continue;
        }
        // A non-empty URL falls through to the single-line checks below.
      }

      final limit = _limits[stem];
      if (limit != null) {
        final codePoints = content.runes.length;
        if (codePoints > limit) {
          violations.add(
            '$where: $codePoints code points exceeds the $limit limit.',
          );
        }
      }

      if (_singleLineFields.contains(stem)) {
        if (content != content.trim()) {
          violations.add(
            '$where: leading or trailing whitespace in a single-line field.',
          );
        }
        if (content.trim().contains('\n')) {
          violations.add('$where: internal newline in a single-line field.');
        }
      }

      if (_requiredTextFields.contains(stem) && content.trim().isEmpty) {
        violations.add('$where: required field is empty.');
      }

      if (stem == 'keywords') {
        final seen = <String>{};
        var flaggedEmpty = false;
        for (final term in content.split(',')) {
          final normalized = term.trim().toLowerCase();
          if (normalized.isEmpty) {
            if (!flaggedEmpty) {
              violations.add(
                '$where: contains an empty keyword term (a stray or trailing '
                'comma).',
              );
              flaggedEmpty = true;
            }
            continue;
          }
          if (!seen.add(normalized)) {
            violations.add('$where: duplicate keyword term "${term.trim()}".');
          }
        }
      }
    }
  }

  for (final warning in warnings) {
    err.writeln('store_metadata_lint: WARNING — $warning');
  }
  for (final violation in violations) {
    err.writeln('store_metadata_lint: $violation');
  }

  final scope = locales.join(', ');
  if (violations.isNotEmpty) {
    final withWarnings = warnings.isEmpty
        ? ''
        : ' (${warnings.length} warning(s))';
    err.writeln(
      'store_metadata_lint: FAIL — ${violations.length} violation(s) across '
      '$scope$withWarnings.',
    );
    return 1;
  }

  final withWarnings = warnings.isEmpty
      ? ''
      : ', ${warnings.length} warning(s)';
  out.writeln('store_metadata_lint: PASS — $scope validated$withWarnings.');
  return 0;
}

String _baseName(String path) {
  final trimmed = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final slash = trimmed.lastIndexOf('/');
  return slash == -1 ? trimmed : trimmed.substring(slash + 1);
}

void _usage(StringSink err) {
  err.writeln(
    'usage: dart tool/store_metadata_lint.dart [--allow-empty-urls] '
    '<locale>...',
  );
}
