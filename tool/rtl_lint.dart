// RTL lint guard (docs/architecture.md §6, docs/frontend-brandkit.md §4):
// layouts must use logical start/end, never physical left/right. The Dart
// analyzer has no rule for this, so this script scans Dart sources for the
// common physical-direction APIs and fails the build when one appears.
//
// Usage:   dart tool/rtl_lint.dart [root]      (default root: app/lib)
// Escape:  a trailing `// rtl-ok` comment on the offending line, for the rare
//          case where a physical direction is genuinely intended.
//
// Line-based by design: cheap, dependency-free, good enough until a proper
// custom_lint rule replaces it (tracked for a future session if it ever
// produces a false negative that matters).

import 'dart:io';

final List<RegExp> bannedPatterns = [
  RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
  RegExp(r'EdgeInsets\.fromLTRB\('),
  RegExp(r'Alignment\.(top|center|bottom)(Left|Right)\b'),
  RegExp(r'TextAlign\.(left|right)\b'),
  RegExp(r'Positioned\(\s*(left|right)\s*:'),
  RegExp(r'BorderRadius\.only\([^)]*\b(top|bottom)(Left|Right)\s*:'),
  RegExp(r'\bTextDirection\.(ltr|rtl)\b'),
];

void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : 'app/lib';
  final dir = Directory(root);
  if (!dir.existsSync()) {
    stderr.writeln('rtl_lint: directory not found: $root');
    exitCode = 2;
    return;
  }

  var violations = 0;
  final dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('// rtl-ok')) continue;
      for (final pattern in bannedPatterns) {
        if (pattern.hasMatch(line)) {
          violations++;
          stderr.writeln(
            '${file.path}:${i + 1}: physical direction API '
            '(${pattern.pattern}) — use logical start/end '
            '(EdgeInsetsDirectional, AlignmentDirectional, TextAlign.start, '
            'PositionedDirectional) or add `// rtl-ok` if intended.',
          );
        }
      }
    }
  }

  if (violations > 0) {
    stderr.writeln('rtl_lint: $violations violation(s).');
    exitCode = 1;
  } else {
    stdout.writeln('rtl_lint: clean.');
  }
}
