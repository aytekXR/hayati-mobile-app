// Coverage gate — fails CI when overall line coverage is below a threshold.
//
// Parses an lcov tracefile (app/coverage/lcov.info, produced by
// `flutter test --coverage`), sums LF: (lines found) and LH: (lines hit) across
// every SF record, and compares the resulting percentage against --min.
//
// Usage:   dart tool/coverage_gate.dart --min <0-100> <path/to/lcov.info>
// Example: dart tool/coverage_gate.dart --min 60 app/coverage/lcov.info
//
// Exit codes: 0 = at/above threshold (PASS), 1 = below threshold (FAIL),
//             64 = usage/input error (bad args, missing/unreadable file, or
//             zero instrumented lines — a silent 0/0 "pass" would defeat the
//             gate).
//
// Ratchet rule (docs/test-suite.md §3): the threshold starts at 60% and rises
// +2% per milestone, never lowered. This tool takes the number as an argument;
// ci.yml carries the current value.

import 'dart:io';

// EX_USAGE from sysexits.h: input/usage error, distinct from a real gate FAIL.
const int _exitUsage = 64;

void main(List<String> args) {
  int? min;
  String? path;

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
  } else {
    stdout.writeln('coverage_gate: PASS.');
  }
}

void _usageError(String message) {
  stderr.writeln('coverage_gate: $message');
  stderr.writeln(
    'usage: dart tool/coverage_gate.dart --min <0-100> <path/to/lcov.info>',
  );
  exitCode = _exitUsage;
}
