// Coverage gate — fails CI when overall line coverage is below a threshold.
//
// Parses an lcov tracefile (app/coverage/lcov.info, produced by
// `flutter test --coverage`), sums LF: (lines found) and LH: (lines hit) across
// every SF record, and compares the resulting percentage against --min.
//
// Usage:   dart tool/coverage_gate.dart --min <0-100> [--max-slack <points>] <lcov>
// Example: dart tool/coverage_gate.dart --min 86 --max-slack 5 app/coverage/lcov.info
//
// Exit codes: 0 = at/above threshold and not decorative (PASS),
//             1 = FAIL — either coverage is below --min, or the floor has
//             drifted more than --max-slack below the measurement,
//             64 = usage/input error (bad args, missing/unreadable file, or
//             zero instrumented lines — a silent 0/0 "pass" would defeat the
//             gate).
//
// ⚠️ WHY THERE ARE TWO FAILURE REASONS ON ONE EXIT CODE (ADR-079 D1).
// Both are FINDINGS: the check ran and found a problem. ADR-041 D2's taxonomy
// separates "measured and found something" (1) from "could not measure" (2/64),
// not one kind of finding from another — `store_metadata_publish.py` likewise
// bundles three distinct defects under its EXIT_FINDING.
//
// ⚠️ AND WHY THE SECOND REASON EXISTS AT ALL. docs/test-suite.md §3 has said
// since the M4 close: "ratchet: starts 60%, +2%/milestone, never lowered — 68
// since the M4 close (measured 86.50%)". The eighteen-point gap was recorded in
// the rule itself and left; by S104 the gate was 68 against a measured 87.75%,
// permitting a ~1,630-line regression while printing PASS every run. A ratchet
// that depends on somebody remembering is prose. --max-slack makes the drift
// itself the failure, at the moment it happens rather than eight milestones
// later, and the message names the floor to write.
//
// ⚠️ WHAT IT CANNOT DO: stop a session satisfying it by widening --max-slack
// instead of raising --min. Nothing mechanical can. What it buys is that the
// choice is an explicit line in ci.yml that a diff shows (ADR-079 D1).

import 'dart:io';

// EX_USAGE from sysexits.h: input/usage error, distinct from a real gate FAIL.
const int _exitUsage = 64;

void main(List<String> args) {
  int? min;
  int? maxSlack;
  String? path;
  var sawMaxSlack = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--min') {
      if (i + 1 >= args.length) {
        _usageError('--min requires a value.');
        return;
      }
      min = int.tryParse(args[++i]);
    } else if (arg.startsWith('--min=')) {
      min = int.tryParse(arg.substring('--min='.length));
    } else if (arg == '--max-slack') {
      sawMaxSlack = true;
      if (i + 1 >= args.length) {
        _usageError('--max-slack requires a value.');
        return;
      }
      maxSlack = int.tryParse(args[++i]);
    } else if (arg.startsWith('--max-slack=')) {
      sawMaxSlack = true;
      maxSlack = int.tryParse(arg.substring('--max-slack='.length));
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

  if (min == null || min < 0 || min > 100) {
    _usageError('--min must be an integer 0-100.');
    return;
  }
  // Validated the same way --min is, and for the same reason ADR-055's watchdog
  // validates its heartbeat: a guard strict about one input and silent about
  // another is this repo's recurring failure shape. A negative slack would make
  // every run decorative-fail; a non-numeric one would silently disable the
  // check, which is worse.
  if (sawMaxSlack && (maxSlack == null || maxSlack < 0 || maxSlack > 100)) {
    _usageError('--max-slack must be an integer 0-100.');
    return;
  }
  if (path == null) {
    _usageError('missing path to lcov.info.');
    return;
  }

  final file = File(path);
  if (!file.existsSync()) {
    _usageError('lcov file not found: $path');
    return;
  }

  final List<String> lines;
  try {
    lines = file.readAsLinesSync();
  } on IOException catch (e) {
    _usageError('cannot read $path: $e');
    return;
  }

  var found = 0;
  var hit = 0;
  for (final line in lines) {
    if (line.startsWith('LF:')) {
      found += int.tryParse(line.substring(3).trim()) ?? 0;
    } else if (line.startsWith('LH:')) {
      hit += int.tryParse(line.substring(3).trim()) ?? 0;
    }
  }

  if (found == 0) {
    stderr.writeln(
      'coverage_gate: no instrumented lines found in $path (LF total is 0). '
      'A 0/0 result cannot pass the gate — check that `flutter test '
      '--coverage` ran and produced coverage.',
    );
    exitCode = _exitUsage;
    return;
  }

  final pct = 100 * hit / found;
  stdout.writeln('coverage_gate: lines found $found, lines hit $hit');
  stdout.writeln('coverage_gate: ${pct.toStringAsFixed(2)}% (threshold $min%)');

  if (pct < min) {
    stderr.writeln(
      'coverage_gate: FAIL — ${pct.toStringAsFixed(2)}% is below the '
      '$min% threshold.',
    );
    exitCode = 1;
    return;
  }

  // THE DECORATIVE CHECK (ADR-079 D1). Floor truncated, never rounded up: a
  // suggested floor above the measurement would fail the next run for no reason.
  if (maxSlack != null) {
    final slack = pct - min;
    stdout.writeln(
      'coverage_gate: slack ${slack.toStringAsFixed(2)} points '
      '(max $maxSlack).',
    );
    if (slack > maxSlack) {
      final suggested = pct.floor();
      stderr.writeln(
        'coverage_gate: FAIL — the floor is ${slack.toStringAsFixed(2)} points '
        'below the measurement, more than the $maxSlack allowed. A gate this '
        'far under what the suite achieves cannot catch a regression: '
        '${(pct - min).toStringAsFixed(2)}% of the codebase could go uncovered '
        'and this check would still say PASS.',
      );
      stderr.writeln(
        'coverage_gate: raise it — set `--min $suggested` in .github/workflows/'
        'ci.yml (docs/test-suite.md §3, ADR-079 D1).',
      );
      exitCode = 1;
      return;
    }
  }

  stdout.writeln('coverage_gate: PASS.');
}

void _usageError(String message) {
  stderr.writeln('coverage_gate: $message');
  stderr.writeln(
    'usage: dart tool/coverage_gate.dart --min <0-100> '
    '[--max-slack <0-100>] <path/to/lcov.info>',
  );
  exitCode = _exitUsage;
}
