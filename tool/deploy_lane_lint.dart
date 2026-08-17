// Deploy-lane lint — fails CI when a dispatch-only deploy lane is missing a
// guard its siblings already carry (ADR-050, issue #223). A credential-free,
// dependency-free source sentinel over `.github/workflows/deploy-*.yml`: pure
// dart:io, runnable in the ubuntu quality job before any `pub get`.
//
// WHY this exists, concretely. Three workflows deploy something a session must
// not deploy casually, each was modelled on the one before it, and only the
// NEWEST carried either guard:
//
//   lane                    ref pin           concurrency
//   deploy-site.yml         none              none
//   deploy-rules.yml        none              none
//   deploy-functions.yml    prod -> main      per project, no-cancel
//
// The oldest lane guarded the least and published the most irreversible thing.
// That is not bad luck: each lane was reviewed against the state of the art at
// the time it was written, and nothing ever went back. Two edits close #223 and
// do nothing about the FOURTH lane, so the rules below are written to catch the
// next instance rather than to re-catch these two.
//
// WHAT THIS PROVES, AND WHAT IT CANNOT (ADR-050 D4). It proves the guards are
// present and well-formed IN THE SOURCE. It cannot prove GitHub honours them:
// that needs a dispatch, which needs FIREBASE_SERVICE_ACCOUNT, which is operator
// item 2(e)(iii). None of these lanes has ever executed. A green run here is
// "the guard is written correctly", never "the guard was tested".
//
// Usage:   dart tool/deploy_lane_lint.dart
//
// Exit codes: 0 = clean (PASS), 1 = violations (FAIL), 64 = usage/input error
//             (no lane found, or a file this lint reads is unreadable — a
//             "couldn't check" must never read as green).

import 'dart:io';

// EX_USAGE from sysexits.h: input error, distinct from a real lint FAIL. Same
// taxonomy as release_lane_lint.dart.
const int _exitUsage = 64;

const String _workflowDir = '.github/workflows';

/// The inputs that can select a **production / public** target, and the value
/// that means production for each.
///
/// A lane is judged against this table by the inputs it actually declares, so a
/// future lane naming its selector something else is NOT silently exempted —
/// [checkLaneIsClassified] fails on a deploy lane that takes inputs this table
/// cannot classify, rather than passing it for lack of an opinion.
const Map<String, String> productionSelectors = {
  'project': 'prod',
  'channel': 'live',
};

/// The ref a production deploy must run from.
const String requiredProdRef = 'refs/heads/main';

/// The commands that actually publish something, by which the lint locates "the
/// deploy step" for [checkProductionRefPin]'s ordering rule.
///
/// Spelled out rather than inferred, because "the step that deploys" is not a
/// property of a step — it is a property of what the step RUNS, and a lint that
/// guessed (the last step? the one named `deploy`?) would be guessing about the
/// one ordering that matters. A lane whose publish command is not in this list
/// is REPORTED, not skipped: either the vocabulary is stale or the file is not a
/// deploy lane, and both want a human.
const List<String> deployCommands = [
  'firebase deploy',
  'firebase hosting:channel:deploy',
];

void main(List<String> args) {
  exitCode = runDeployLaneLint(args, out: stdout, err: stderr);
}

/// In-process entrypoint so the self-tests can drive the lint against a temp
/// tree without spawning a VM per case. [root] is the repo root.
int runDeployLaneLint(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  String root = '.',
}) {
  if (args.isNotEmpty) {
    err.writeln('Usage: dart tool/deploy_lane_lint.dart');
    return _exitUsage;
  }

  final dir = Directory('$root/$_workflowDir');
  if (!dir.existsSync()) {
    err.writeln(
      'deploy-lane lint: $_workflowDir not found. This lint reads it, so a '
      'missing directory is an input error, never a pass.',
    );
    return _exitUsage;
  }

  // DERIVED, not hand-maintained: a fourth deploy lane is guarded the day it is
  // added rather than the day someone remembers ADR-050.
  final lanes =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => _laneName(f.path) != null)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // ⚠️ An empty derived set is the greenest thing in this repo and measures
  // nothing — the `lock_screen_forbidden_api_sentinel_test` sentinel-of-the-
  // sentinel, applied here. If the glob stops matching (a rename, a move), that
  // is a broken lint, not a clean tree.
  if (lanes.isEmpty) {
    err.writeln(
      'deploy-lane lint: no $_workflowDir/deploy-*.yml found. The lane list is '
      'DERIVED from that glob, so an empty set means this lint is checking '
      'nothing — which is an input error, never a pass.',
    );
    return _exitUsage;
  }

  final violations = <String>[];
  final passes = <String>[];

  for (final file in lanes) {
    final name = _laneName(file.path)!;
    final String source;
    try {
      source = file.readAsStringSync();
    } on FileSystemException catch (failure) {
      err.writeln(
        'deploy-lane lint: cannot read ${file.path}: ${failure.message}',
      );
      return _exitUsage;
    }
    violations.addAll(checkLaneIsClassified(name, source, passes));
    violations.addAll(checkConcurrency(name, source, passes));
    violations.addAll(checkProductionRefPin(name, source, passes));
  }

  for (final line in passes) {
    out.writeln('  ok   $line');
  }
  if (violations.isEmpty) {
    out.writeln(
      'deploy-lane lint: PASS (${passes.length} checks over ${lanes.length} lane(s))',
    );
    return 0;
  }
  err.writeln('');
  for (final v in violations) {
    err.writeln('  FAIL $v');
  }
  err.writeln('');
  err.writeln(
    'deploy-lane lint: ${violations.length} violation(s). See ADR-050 and issue #223.',
  );
  return 1;
}

/// `deploy-foo.yml` -> `deploy-foo`; anything else -> null.
String? _laneName(String path) {
  final base = path.split(Platform.pathSeparator).last;
  if (!base.startsWith('deploy-') || !base.endsWith('.yml')) return null;
  return base.substring(0, base.length - 4);
}

/// RULE 0 — every deploy lane must be CLASSIFIABLE.
///
/// ⚠️ This rule exists because its absence was a lie the file told about itself.
/// [productionSelectors]'s doc comment claimed a lane this table cannot classify
/// is failed "rather than passed for lack of an opinion" — and **no such check
/// existed**. A fourth lane declaring `environment: [staging, production]` would
/// have had [checkProductionRefPin] return an empty list and passed the whole
/// lint with no ref guard at all, while the header promised the opposite. The
/// design review's skeptic found it by reading for the named function and not
/// finding it.
///
/// A lane with **no** dispatch inputs is legitimately unclassifiable and needs no
/// pin: it cannot select anything. What must never pass silently is a lane that
/// DOES take target-shaped inputs this lint does not know.
List<String> checkLaneIsClassified(
  String lane,
  String source,
  List<String> passes,
) {
  if (_productionSelector(source) != null) return const [];
  final declared = RegExp(
    r'^ {6}([a-z_][a-z0-9_]*):',
    multiLine: true,
  ).allMatches(source).map((m) => m.group(1)!).toSet();
  if (declared.isEmpty) {
    passes.add('$lane declares no dispatch inputs, so it selects no target');
    return const [];
  }
  final known = productionSelectors.entries
      .map((e) => '${e.key}=${e.value}')
      .join(', ');
  return [
    '$lane: declares input(s) ${declared.join(', ')}, none of which this lint '
        'can classify as selecting production ($known). Either this lane cannot '
        'reach production — in which case say so by naming its inputs the way '
        'the others do — or add its selector to productionSelectors. A lane '
        'nobody can classify is a lane nobody guards (ADR-050 D4).',
  ];
}

/// RULE 1 — every deploy lane declares `concurrency`, per target, never cancelling
/// (ADR-050 D3).
///
/// Two overlapping dispatches against one target are two clients racing over one
/// artifact. **`cancel-in-progress: false` is the load-bearing half**: a deploy
/// killed mid-flight is strictly worse than one that waits (ADR-048 D10 names the
/// Functions case — the partially-applied state the read-back exists to catch).
///
/// The group must INTERPOLATE the target. A constant group is not merely weaker:
/// it makes a dev deploy queue behind a prod one, which is a new bug rather than
/// a weaker guard, so this rule fails on it rather than shrugging.
List<String> checkConcurrency(String lane, String source, List<String> passes) {
  final violations = <String>[];
  final selector = _productionSelector(source)?.$1;
  final block = _workflowLevelBlock(source, 'concurrency');
  if (block == null) {
    return [
      '$lane: no workflow-level `concurrency` block. Two dispatches against one '
          'target would race (ADR-050 D3). Add `concurrency: { group: '
          '$lane-\${{ github.event.inputs.<selector> }}, cancel-in-progress: false }`.',
    ];
  }

  if (!RegExp(r'cancel-in-progress:\s*false').hasMatch(block)) {
    violations.add(
      '$lane: `concurrency` does not set `cancel-in-progress: false`. That half '
      'is load-bearing — a deploy killed mid-flight is worse than one that '
      'waits (ADR-050 D3).',
    );
  } else {
    passes.add('$lane concurrency queues rather than cancels');
  }

  final group = RegExp(r'group:\s*(.+)').firstMatch(block)?.group(1)?.trim();
  if (group == null) {
    violations.add('$lane: `concurrency` has no `group:`.');
  } else if (!group.contains(r'${{')) {
    violations.add(
      '$lane: concurrency group `$group` is a CONSTANT, so a dev deploy would '
      'queue behind a prod one — a new bug, not a weaker guard. Interpolate '
      'the target selector (ADR-050 D3).',
    );
  } else if (!group.contains('github.event.inputs.')) {
    // ADR-048 D10 / ADR-050 D3: workflow-level `concurrency` is evaluated
    // BEFORE any job starts, so a bad expression there is a PARSE error — and a
    // dispatch-only lane's first real parse is someone's first dispatch, on a
    // live project. The explicit context is the one that is unambiguously
    // available there.
    violations.add(
      '$lane: concurrency group `$group` does not use `github.event.inputs.`. '
      'Workflow-level concurrency is evaluated before any job starts, so a '
      'bad expression there is a PARSE error on someone\'s first dispatch '
      '(ADR-050 D3).',
    );
  } else if (selector != null &&
      !group.contains('github.event.inputs.$selector')) {
    // Keying on SOME input is not keying on the TARGET. A group of
    // `deploy-rules-${{ github.event.inputs.confirm_prod }}` interpolates
    // faithfully and serializes nothing useful: two prod dispatches that both
    // typed the id collide by luck, and a prod and a dev dispatch land in
    // different groups only if the typing happened to differ. Checked AFTER the
    // context rule above so a lane that gets both wrong is told about both, one
    // at a time, rather than being sent to fix the less important one.
    violations.add(
      '$lane: concurrency group `$group` does not key on `$selector`, the input '
      'that selects the target. Keying on another input serializes the wrong '
      'pairs (ADR-050 D3).',
    );
  } else {
    passes.add('$lane concurrency group is per target');
  }
  return violations;
}

/// RULE 2 — a lane that can select production pins that dispatch to `main`
/// (ADR-050 D1/D2).
///
/// A `workflow_dispatch` runs against whatever ref the dispatcher picks, and a
/// typed confirmation does not help: it confirms which PROJECT, never which
/// CODE. The guard must therefore name BOTH the production selector and the ref
/// — a guard on the ref alone would pin every dispatch to `main` and break dev,
/// which is the fix overshooting into a different bug.
List<String> checkProductionRefPin(
  String lane,
  String source,
  List<String> passes,
) {
  final selector = _productionSelector(source);
  if (selector == null) {
    // Not a lane that can reach production from an input, OR a lane this lint
    // cannot classify. Both are reported by RULE 3; nothing to pin here.
    return const [];
  }
  final (input, prodValue) = selector;

  // The guard is a step-level `if:` that must name the production value and the
  // required ref TOGETHER. Both halves in one expression is the point: separate
  // conditions could be satisfied by two different steps that never co-occur.
  //
  // ⚠️ OPERATORS ARE CHECKED, not merely the operands. A substring scan for
  // `inputs.project` + `'prod'` + `github.ref` + `refs/heads/main` also matches
  //
  //     if: inputs.project != 'prod' && github.ref != 'refs/heads/main'
  //
  // which blocks DEV from a branch and lets PROD through from anywhere — the
  // guard inverted into precisely the hole it was added to close, passing a lint
  // that only looked for words. So the equality on the input and the inequality
  // on the ref are both required, spelled out.
  // ⚠️ COMMENTS ARE STRIPPED FIRST. Every one of these lanes now carries a header
  // explaining the guard, quoting the very expression this rule looks for — and
  // `deploy_lane_lint.dart`'s own prose does too. A lint satisfied by a comment
  // about a guard is satisfied by the remediation note left behind when someone
  // DELETES the guard, which is the worst possible moment to go green
  // (release_lane_lint.dart's "scan CODE, not commentary" rule, same reasoning).
  final code = source
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'^\s*#.*'), ''))
      .join('\n');
  final guards = RegExp(r'if:\s*\$\{\{([^}]*)\}\}').allMatches(code);
  for (final match in guards) {
    final expression = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
    // ⚠️ AND, NOT OR — a SECOND inversion, distinct from the `!=` one above.
    // `inputs.project == 'prod' || github.ref != 'refs/heads/main'` contains
    // both required substrings and fires on every dev dispatch from a branch:
    // the guard blocking the deploys it was never meant to touch, while still
    // reading as correct to anyone checking for the right words. So the
    // conjunction itself is asserted, in either operand order.
    final conjunction =
        "inputs.$input == '$prodValue' && github.ref != '$requiredProdRef'";
    final reversed =
        "github.ref != '$requiredProdRef' && inputs.$input == '$prodValue'";
    if (expression.contains(conjunction) || expression.contains(reversed)) {
      // ⚠️ ORDER IS THE WHOLE POINT. A guard step placed AFTER the deploy step
      // is not a weaker guard, it is decoration: the thing it exists to prevent
      // has already happened by the time it runs, and the run still goes red so
      // it even LOOKS like it worked.
      final guardAt = match.start;
      final deployAt = deployCommands
          .map((cmd) => code.indexOf(cmd))
          .where((i) => i >= 0)
          .fold<int>(-1, (lowest, i) => lowest < 0 || i < lowest ? i : lowest);
      if (deployAt < 0) {
        return [
          '$lane: no step runs any of ${deployCommands.join(', ')}, so this lint '
              'cannot tell whether the ref guard precedes the deploy. Either the '
              'lane publishes some other way (add it to deployCommands) or this '
              'is not a deploy lane (rename it).',
        ];
      }
      if (guardAt > deployAt) {
        return [
          '$lane: the `$input=$prodValue` ref guard appears AFTER the deploy '
              'command. A guard that runs once the deploy has happened prevents '
              'nothing and still reddens the run, so it reads as working '
              '(ADR-050 D4).',
        ];
      }
      passes.add(
        '$lane pins $input=$prodValue to $requiredProdRef, before it deploys',
      );
      return const [];
    }
  }
  return [
    '$lane: `$input: $prodValue` can be dispatched from ANY ref. A typed '
        'confirmation says which project, never which code, and a branch deploy '
        'manufactures the drift the drift-checkers exist to report (ADR-050 '
        'D1/D2). Add a step guarded on '
        '`inputs.$input == \'$prodValue\' && github.ref != \'$requiredProdRef\'` '
        'that exits 1.',
  ];
}

/// The (input, production-value) pair this lane uses, or null when it declares
/// none of [productionSelectors].
(String, String)? _productionSelector(String source) {
  for (final entry in productionSelectors.entries) {
    if (RegExp('^\\s{6}${entry.key}:', multiLine: true).hasMatch(source) &&
        source.contains("'${entry.value}'") |
            source.contains('[${entry.value}') |
            source.contains(', ${entry.value}]')) {
      return (entry.key, entry.value);
    }
  }
  return null;
}

/// The body of a top-level `key:` block, from its line to the next top-level
/// key. Returns null when the key is absent at column 0.
///
/// Deliberately crude and deliberately anchored at column 0: this lint reads
/// WORKFLOW-LEVEL declarations, and a `concurrency:` nested inside a job is a
/// different thing with different semantics that must not satisfy Rule 1.
String? _workflowLevelBlock(String source, String key) {
  final lines = source.split('\n');
  final start = lines.indexWhere((l) => l.startsWith('$key:'));
  if (start < 0) return null;
  final rest = lines.skip(start + 1).toList();
  var end = rest.indexWhere(
    (l) => l.isNotEmpty && !l.startsWith(' ') && !l.startsWith('#'),
  );
  if (end < 0) end = rest.length;
  return [lines[start], ...rest.take(end)].join('\n');
}
