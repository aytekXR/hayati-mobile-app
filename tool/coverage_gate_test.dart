// The self-test for coverage_gate.dart (ADR-079 D5).
//
// ⚠️ WHY THIS EXISTS AT ALL, and it is the tidiest illustration of the ADR's own
// subject. Counted across the repo when ADR-079 was written: **20 of 24 tools
// have a `<name>_test.<ext>` beside them, and `coverage_gate.dart` was one of
// the four that did not.** The gate this repo relies on to catch a coverage
// regression had never been exercised except by passing — its 0/0 path, its
// argument parsing and its exit taxonomy were all untested. A guard nobody has
// watched fail is a claim.
//
// Run: dart tool/coverage_gate_test.dart   (hermetic — writes lcov fixtures to
// a temp dir, shells the real tool, asserts on exit code and output).
//
// THE MUTATIONS ARE ENUMERATED IN ADR-079 D5, BEFORE THE GUARD WAS WRITTEN.
// S102 and S103 each paid for learning that twice in one session: a guard whose
// failure you have never seen is not a guard.

import 'dart:io';

int _pass = 0;
int _fail = 0;

void _ok(String what) {
  _pass++;
  stdout.writeln('  ok   $what');
}

void _bad(String what, [String? detail]) {
  _fail++;
  stderr.writeln('  FAIL $what');
  if (detail != null) stderr.writeln('       $detail');
}

/// An lcov tracefile with one record of [found] lines, [hit] of them covered.
String _lcov({
  required int found,
  required int hit,
  String file = 'lib/a.dart',
}) {
  final b = StringBuffer()..writeln('SF:$file');
  for (var i = 1; i <= found; i++) {
    b.writeln('DA:$i,${i <= hit ? 1 : 0}');
  }
  return (b
        ..writeln('LF:$found')
        ..writeln('LH:$hit')
        ..writeln('end_of_record'))
      .toString();
}

({int code, String out}) _run(List<String> args) {
  final r = Process.runSync('dart', ['tool/coverage_gate.dart', ...args]);
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  stdout.writeln('coverage_gate_test');
  final tmp = Directory.systemTemp.createTempSync('covgate');
  String fixture(String name, String body) {
    final f = File('${tmp.path}/$name')..writeAsStringSync(body);
    return f.path;
  }

  try {
    // ---------------------------------------------------------------------
    // 1. The band: below, inside, above.
    // ---------------------------------------------------------------------
    final low = fixture('low.info', _lcov(found: 100, hit: 50)); // 50%
    final mid = fixture('mid.info', _lcov(found: 100, hit: 88)); // 88%
    final high = fixture('high.info', _lcov(found: 100, hit: 99)); // 99%

    var r = _run(['--min', '86', low]);
    if (r.code != 1) {
      _bad('below --min FAILS with exit 1', 'code=${r.code}');
    } else if (!r.out.contains('below the 86% threshold')) {
      _bad('below --min says WHY', r.out);
    } else {
      _ok('below --min FAILS with exit 1');
    }

    r = _run(['--min', '86', '--max-slack', '5', mid]);
    if (r.code != 0) {
      _bad('inside the band PASSES', 'code=${r.code}\n${r.out}');
    } else {
      _ok('inside the band PASSES');
    }

    // ⚠️ THE NEW GUARD (ADR-079 D1). 99% against a floor of 86 is 13 points of
    // slack — the shape that let 68 sit under a measured 87.75% for eight
    // milestones while every run said PASS.
    r = _run(['--min', '86', '--max-slack', '5', high]);
    if (r.code != 1) {
      _bad('a DECORATIVE gate FAILS', 'code=${r.code}\n${r.out}');
    } else if (!r.out.contains('--min 99')) {
      // It must name the floor to write, or the next session has the same
      // argument with the same file.
      _bad('the decorative failure NAMES the floor to write', r.out);
    } else {
      _ok('a DECORATIVE gate FAILS, and names the floor to write');
    }

    // ---------------------------------------------------------------------
    // 2. Backward compatibility: no --max-slack means the old behaviour,
    //    exactly. Every existing caller must be unaffected.
    // ---------------------------------------------------------------------
    r = _run(['--min', '86', high]);
    if (r.code != 0) {
      _bad(
        'without --max-slack the slack check is OFF',
        'code=${r.code}\n${r.out}',
      );
    } else {
      _ok('without --max-slack the slack check is OFF');
    }

    // ---------------------------------------------------------------------
    // 3. ⚠️ COULD-NOT-MEASURE MUST NEVER READ AS GREEN (the tool's own 0/0
    //    precedent, and ADR-041/ADR-047 D4's taxonomy).
    // ---------------------------------------------------------------------
    final empty = fixture(
      'empty.info',
      'SF:lib/a.dart\nLF:0\nLH:0\nend_of_record\n',
    );
    r = _run(['--min', '86', '--max-slack', '5', empty]);
    if (r.code != 64) {
      _bad('0/0 exits 64, not 0 and not 1', 'code=${r.code}\n${r.out}');
    } else {
      _ok('0/0 exits 64 — could-not-measure is not a pass');
    }

    r = _run(['--min', '86', '${tmp.path}/nope.info']);
    if (r.code != 64)
      _bad('a missing lcov exits 64', 'code=${r.code}');
    else
      _ok('a missing lcov exits 64');

    // ---------------------------------------------------------------------
    // 4. Argument validation, including the new one.
    // ---------------------------------------------------------------------
    for (final bad in <List<String>>[
      ['--min', '101', mid],
      ['--min', 'abc', mid],
      ['--min', '86', '--max-slack', 'abc', mid],
      ['--min', '86', '--max-slack', '-1', mid],
    ]) {
      r = _run(bad);
      if (r.code != 64) {
        _bad('rejects ${bad.join(' ')}', 'code=${r.code}\n${r.out}');
      } else {
        _ok('rejects ${bad.join(' ')}');
      }
    }

    // ---------------------------------------------------------------------
    // 5. ⚠️ LESSON 164 — what would stop the gate running at all?
    //
    //    The tool can be perfect and never invoked. `ci.yml` is the source of
    //    truth and is PARSED here rather than restated, the shape
    //    integration_watchdog_test.sh already uses for ADR-055's arithmetic —
    //    a constant copied into a test drifts from the workflow silently.
    // ---------------------------------------------------------------------
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    final invocation = RegExp(
      r'dart tool/coverage_gate\.dart([^\n]*)',
    ).firstMatch(ci);
    if (invocation == null) {
      _bad(
        'ci.yml still INVOKES the coverage gate',
        'no `dart tool/coverage_gate.dart` line in ci.yml — the gate is not running',
      );
    } else {
      final args = invocation.group(1)!;
      _ok('ci.yml still invokes the coverage gate');
      if (!args.contains('--max-slack')) {
        _bad(
          'ci.yml passes --max-slack, or the decorative check is dead',
          args,
        );
      } else {
        _ok('ci.yml passes --max-slack — the decorative check is live');
      }
      // Both numbers must live in the workflow, where a diff shows them. D1
      // cannot stop a session widening the slack; it can make it visible.
      final min = RegExp(r'--min\s+(\d+)').firstMatch(args);
      final slack = RegExp(r'--max-slack\s+(\d+)').firstMatch(args);
      if (min == null || slack == null) {
        _bad('both bounds are literals in ci.yml', args);
      } else {
        _ok(
          'both bounds are literals in ci.yml (--min ${min.group(1)}, '
          '--max-slack ${slack.group(1)})',
        );
      }
    }

    // And the step that PRODUCES the coverage must still ask for it: a dropped
    // `--coverage` leaves a stale or absent lcov, and only the absent case is
    // caught by the 0/0 path above.
    if (!ci.contains('flutter test --coverage')) {
      _bad(
        'ci.yml still runs `flutter test --coverage`',
        'without it the gate reads a stale or missing lcov',
      );
    } else {
      _ok('ci.yml still runs `flutter test --coverage`');
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }

  stdout.writeln();
  if (_fail > 0) {
    stderr.writeln('coverage_gate_test: $_pass passed, $_fail FAILED');
    exit(1);
  }
  stdout.writeln('coverage_gate_test: $_pass passed.');
}
