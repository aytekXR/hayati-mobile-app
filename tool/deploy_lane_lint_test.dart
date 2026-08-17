// Hermetic self-tests for tool/deploy_lane_lint.dart. No network, no
// credential, no `pub get` — pure dart:io against temp trees, so it runs in the
// quality job beside release_lane_lint_test.dart.
//
// WHAT THIS GATE IS FOR. The lint guards three workflows that have NEVER RUN and
// cannot run until operator 2(e)(iii) lands a secret. Nothing else in this repo
// can tell whether their guards are correct — there is no dispatch to observe,
// no log to read, and `actionlint` is not installed. So these tests are the
// entire protection for the instrument, exactly as rules_drift_test.py is for
// its tool, and if they are weak the lint rots invisibly.
//
// The assertions therefore aim at the two ways a lint like this fails:
//
//   * it PASSES something broken — a constant concurrency group, a guard that
//     names the ref but not the production input (which would pin dev to main
//     too), a `concurrency:` nested in a job rather than at workflow level, a
//     guard whose `if:` mentions the right words in two different steps;
//   * it CHECKS NOTHING and says PASS — the derived lane glob matching an empty
//     set, which is the greenest possible output of a sentinel over nothing.
//
// Run: dart tool/deploy_lane_lint_test.dart

import 'dart:io';

import 'deploy_lane_lint.dart';

int _failures = 0;

void check(String name, bool condition, [String detail = '']) {
  if (condition) return;
  _failures++;
  stderr.writeln('  FAIL $name${detail.isEmpty ? '' : ': $detail'}');
}

/// Runs the lint over a temp tree containing exactly [lanes].
({int code, String out, String err}) runOn(Map<String, String> lanes) {
  final dir = Directory.systemTemp.createTempSync('deploy-lane-lint-');
  try {
    final wf = Directory('${dir.path}/.github/workflows')
      ..createSync(recursive: true);
    lanes.forEach((name, body) {
      File('${wf.path}/$name').writeAsStringSync(body);
    });
    final out = StringBuffer();
    final err = StringBuffer();
    final code = runDeployLaneLint(
      const [],
      out: out,
      err: err,
      root: dir.path,
    );
    return (code: code, out: out.toString(), err: err.toString());
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// A lane with both guards correct — the shape every rule below mutates.
String goodLane({
  String selector = 'project',
  String prodValue = 'prod',
  String devValue = 'dev',
  String concurrency = '''
concurrency:
  group: deploy-thing-\${{ github.event.inputs.project }}
  cancel-in-progress: false
''',
  String guard = '''
      - name: prod deploys only from main
        if: \${{ inputs.project == 'prod' && github.ref != 'refs/heads/main' }}
        run: exit 1
''',
}) =>
    '''
name: deploy-thing

on:
  workflow_dispatch:
    inputs:
      $selector:
        description: 'which target'
        required: true
        default: $devValue
        type: choice
        options: [$devValue, $prodValue]

permissions:
  contents: read

$concurrency
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
$guard
      - name: deploy
        run: firebase deploy --only thing
''';

void main() {
  // ---- the load-bearing positive control -------------------------------------
  // If this fails, every "mutant is caught" result below is meaningless: they
  // would all be failing for whatever reason this one does.
  final good = runOn({'deploy-thing.yml': goodLane()});
  check('good-lane/passes', good.code == 0, 'exit ${good.code}\n${good.err}');
  check(
    'good-lane/reports-both-guards',
    good.out.contains('queues rather than cancels') &&
        good.out.contains('per target') &&
        good.out.contains('pins project=prod'),
    good.out,
  );

  // ---- RULE 1: concurrency ---------------------------------------------------
  final noConcurrency = runOn({'deploy-thing.yml': goodLane(concurrency: '')});
  check('concurrency/absent-fails', noConcurrency.code == 1);
  check(
    'concurrency/absent-names-the-fix',
    noConcurrency.err.contains('cancel-in-progress: false'),
    'the message must say what to add, not merely that something is missing',
  );

  final cancels = runOn({
    'deploy-thing.yml': goodLane(
      concurrency: '''
concurrency:
  group: deploy-thing-\${{ github.event.inputs.project }}
  cancel-in-progress: true
''',
    ),
  });
  check('concurrency/cancel-true-fails', cancels.code == 1, cancels.out);
  check(
    'concurrency/cancel-true-explains-why',
    cancels.err.contains('worse than one that waits'),
  );

  // A CONSTANT group is not a weaker guard, it is a different bug: dev queues
  // behind prod. The lint must say so rather than accept it.
  final constantGroup = runOn({
    'deploy-thing.yml': goodLane(
      concurrency: '''
concurrency:
  group: deploy-thing
  cancel-in-progress: false
''',
    ),
  });
  check(
    'concurrency/constant-group-fails',
    constantGroup.code == 1,
    constantGroup.out,
  );
  check(
    'concurrency/constant-group-names-the-consequence',
    constantGroup.err.contains('queue behind a prod one'),
  );

  // The bare `inputs` context: resolves in some places, and workflow-level
  // concurrency is evaluated before any job starts, so a bad expression there is
  // a PARSE error on someone's first dispatch (ADR-048 D10, ADR-050 D3).
  final bareInputs = runOn({
    'deploy-thing.yml': goodLane(
      concurrency: '''
concurrency:
  group: deploy-thing-\${{ inputs.project }}
  cancel-in-progress: false
''',
    ),
  });
  check('concurrency/bare-inputs-fails', bareInputs.code == 1, bareInputs.out);
  check(
    'concurrency/bare-inputs-explains-parse-risk',
    bareInputs.err.contains('PARSE error'),
  );

  // ⚠️ A `concurrency:` nested inside a JOB is a different thing with different
  // semantics. Accepting it would be the lint passing a lane whose workflow-level
  // races are entirely unguarded.
  final jobLevel = runOn({
    'deploy-thing.yml': goodLane(concurrency: '').replaceFirst(
      '  deploy:\n    runs-on:',
      '  deploy:\n    concurrency:\n      group: x-\${{ github.event.inputs.project }}\n      cancel-in-progress: false\n    runs-on:',
    ),
  });
  check(
    'concurrency/job-level-does-not-satisfy-workflow-level',
    jobLevel.code == 1,
    'a job-level concurrency block must not satisfy the workflow-level rule',
  );

  // Keying on SOME input is not keying on the TARGET. This group interpolates
  // faithfully and serializes the wrong pairs.
  final wrongKey = runOn({
    'deploy-thing.yml': goodLane(
      concurrency: '''
concurrency:
  group: deploy-thing-\${{ github.event.inputs.confirm_prod }}
  cancel-in-progress: false
''',
    ),
  });
  check('concurrency/wrong-input-key-fails', wrongKey.code == 1, wrongKey.out);
  check(
    'concurrency/wrong-input-key-names-the-selector',
    wrongKey.err.contains('does not key on `project`'),
    wrongKey.err,
  );

  // ---- RULE 2: the production ref pin ---------------------------------------
  final noGuard = runOn({'deploy-thing.yml': goodLane(guard: '')});
  check('refpin/absent-fails', noGuard.code == 1);
  check(
    'refpin/absent-names-both-halves',
    noGuard.err.contains("inputs.project == 'prod'") &&
        noGuard.err.contains('refs/heads/main'),
  );

  // THE OVERSHOOT. A guard on the ref alone pins EVERY dispatch to main, which
  // breaks dev — the fix turning into a different bug. It must not pass.
  final refOnly = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: only from main
        if: \${{ github.ref != 'refs/heads/main' }}
        run: exit 1
''',
    ),
  });
  check('refpin/ref-only-guard-fails', refOnly.code == 1, refOnly.out);

  // The mirror: naming the input but not the ref guards nothing about the code.
  final prodOnly = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: prod needs confirmation
        if: \${{ inputs.project == 'prod' }}
        run: exit 1
''',
    ),
  });
  check('refpin/input-only-guard-fails', prodOnly.code == 1, prodOnly.out);

  // ⚠️ THE INVERTED GUARD, and the one a word-matching lint passes. Every token
  // the rule looks for is present — the input, the production value, github.ref,
  // the required ref — and the meaning is exactly backwards: DEV is blocked from
  // a branch and PROD sails through from anywhere. The guard turned into the
  // hole it was added to close.
  final inverted = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: prod deploys only from main
        if: \${{ inputs.project != 'prod' && github.ref != 'refs/heads/main' }}
        run: exit 1
''',
    ),
  });
  check('refpin/inverted-guard-fails', inverted.code == 1, inverted.out);

  // The mirror inversion: firing when the ref IS main is a guard that blocks the
  // only dispatch that should be allowed.
  final invertedRef = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: prod deploys only from main
        if: \${{ inputs.project == 'prod' && github.ref == 'refs/heads/main' }}
        run: exit 1
''',
    ),
  });
  check(
    'refpin/inverted-ref-comparison-fails',
    invertedRef.code == 1,
    invertedRef.out,
  );

  // Whitespace and formatting must not decide correctness.
  final tightlyFormatted = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: prod deploys only from main
        if: \${{ inputs.project == 'prod'
              && github.ref != 'refs/heads/main' }}
        run: exit 1
''',
    ),
  });
  check(
    'refpin/multiline-expression-accepted',
    tightlyFormatted.code == 0,
    tightlyFormatted.err,
  );

  // SPLIT ACROSS TWO STEPS. Each half exists somewhere in the file, and together
  // they guard nothing — the two conditions can never co-occur in one step. A
  // lint that grepped the whole file for both strings would pass this.
  final split = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: prod needs confirmation
        if: \${{ inputs.project == 'prod' }}
        run: echo confirmed
      - name: main only
        if: \${{ github.ref != 'refs/heads/main' }}
        run: echo on a branch
''',
    ),
  });
  check(
    'refpin/split-across-steps-fails',
    split.code == 1,
    'both halves present in different steps must NOT satisfy the rule',
  );

  // ⚠️ A COMMENT ABOUT THE GUARD IS NOT THE GUARD. Every one of these lanes now
  // carries a header quoting the very expression the rule looks for, so a lint
  // that scanned raw text would be satisfied by the remediation note somebody
  // leaves behind when they DELETE the guard — going green at the worst possible
  // moment.
  final commentedGuard = runOn({
    'deploy-thing.yml': goodLane(guard: '').replaceFirst(
      'jobs:',
      "# The guard this lane needs is:\n"
          "#        if: \${{ inputs.project == 'prod' && github.ref != 'refs/heads/main' }}\njobs:",
    ),
  });
  check(
    'refpin/a-comment-is-not-a-guard',
    commentedGuard.code == 1,
    'a commented-out guard must not satisfy the rule',
  );

  // ⚠️ A GUARD AFTER THE DEPLOY IS DECORATION. The thing it exists to prevent has
  // already happened when it runs — and the run still goes red, so it even looks
  // like it worked.
  final guardAfterDeploy = runOn({
    'deploy-thing.yml':
        goodLane(guard: '') +
        '''
      - name: prod deploys only from main
        if: \${{ inputs.project == 'prod' && github.ref != 'refs/heads/main' }}
        run: exit 1
''',
  });
  check(
    'refpin/guard-after-deploy-fails',
    guardAfterDeploy.code == 1,
    guardAfterDeploy.out,
  );
  check(
    'refpin/guard-after-deploy-says-why',
    guardAfterDeploy.err.contains('prevents nothing'),
    guardAfterDeploy.err,
  );

  // A lane whose publish command this lint does not know is REPORTED, never
  // skipped: silently not checking the ordering is the same green as checking it.
  final unknownDeployCommand = runOn({
    'deploy-thing.yml': goodLane().replaceFirst(
      'firebase deploy --only thing',
      'gcloud run deploy thing',
    ),
  });
  check(
    'refpin/unknown-publish-command-is-reported',
    unknownDeployCommand.code == 1,
    unknownDeployCommand.out,
  );
  check(
    'refpin/unknown-publish-command-names-both-fixes',
    unknownDeployCommand.err.contains('deployCommands') &&
        unknownDeployCommand.err.contains('rename it'),
    unknownDeployCommand.err,
  );

  // ---- the `channel: live` selector, i.e. deploy-site's shape ---------------
  final siteShape = runOn({
    'deploy-site.yml': goodLane(
      selector: 'channel',
      prodValue: 'live',
      devValue: 'preview',
      concurrency: '''
concurrency:
  group: deploy-site-\${{ github.event.inputs.channel }}
  cancel-in-progress: false
''',
      guard: '''
      - name: live publishes only from main
        if: \${{ inputs.channel == 'live' && github.ref != 'refs/heads/main' }}
        run: exit 1
''',
    ),
  });
  check('selector/channel-live-recognised', siteShape.code == 0, siteShape.err);
  check(
    'selector/channel-live-reported',
    siteShape.out.contains('pins channel=live'),
    siteShape.out,
  );

  // ⚠️ THE SECOND INVERSION, and the one my own operator fix did NOT catch.
  // `== 'prod' || ref != 'main'` contains both required substrings and fires on
  // EVERY dev dispatch from a branch — the guard blocking exactly the deploys it
  // was never meant to touch, while reading as correct to anyone checking words.
  final orInsteadOfAnd = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: prod deploys only from main
        if: \${{ inputs.project == 'prod' || github.ref != 'refs/heads/main' }}
        run: exit 1
''',
    ),
  });
  check(
    'refpin/or-instead-of-and-fails',
    orInsteadOfAnd.code == 1,
    orInsteadOfAnd.out,
  );

  // Operand order is style, not meaning: the conjunction is accepted either way.
  final reversedOperands = runOn({
    'deploy-thing.yml': goodLane(
      guard: '''
      - name: prod deploys only from main
        if: \${{ github.ref != 'refs/heads/main' && inputs.project == 'prod' }}
        run: exit 1
''',
    ),
  });
  check(
    'refpin/operand-order-is-style',
    reversedOperands.code == 0,
    reversedOperands.err,
  );

  // ---- RULE 0: a lane nobody can classify is a lane nobody guards -----------
  // ⚠️ The lint's own header CLAIMED this check existed before it did. A fourth
  // lane with an unrecognised selector would have skipped the ref-pin rule
  // entirely and passed with no guard at all.
  final unclassifiable = runOn({
    'deploy-config.yml': goodLane(
      selector: 'environment',
      prodValue: 'production',
      devValue: 'staging',
      guard: '',
    ),
  });
  check(
    'classify/unknown-selector-is-reported',
    unclassifiable.code == 1,
    'a lane taking a target-shaped input this lint cannot classify must NOT pass',
  );
  check(
    'classify/unknown-selector-names-both-fixes',
    unclassifiable.err.contains('productionSelectors') &&
        unclassifiable.err.contains('nobody guards'),
    unclassifiable.err,
  );

  // ---- the derived lane list ------------------------------------------------
  // A sentinel over an empty set is the greenest thing in this repo and measures
  // nothing. It must be an INPUT ERROR, distinct from both PASS and FAIL.
  final empty = runOn({'ci.yml': 'name: ci\n'});
  check(
    'derived/empty-set-is-not-a-pass',
    empty.code == 64,
    'exit ${empty.code}',
  );
  check(
    'derived/empty-set-says-why',
    empty.err.contains('checking nothing'),
    empty.err,
  );

  // Non-deploy workflows are not lanes and must not be dragged in.
  final ignoresOthers = runOn({
    'deploy-thing.yml': goodLane(),
    'release.yml': 'name: release\non:\n  workflow_dispatch:\n',
    'ci.yml': 'name: ci\n',
  });
  check(
    'derived/ignores-non-deploy-workflows',
    ignoresOthers.code == 0,
    ignoresOthers.err,
  );

  // Every lane is checked, not just the first — a loop that returned early would
  // pass a broken second lane.
  final secondLaneBroken = runOn({
    'deploy-aaa.yml': goodLane(),
    'deploy-zzz.yml': goodLane(guard: ''),
  });
  check(
    'derived/checks-every-lane',
    secondLaneBroken.code == 1,
    secondLaneBroken.out,
  );
  check(
    'derived/names-the-offending-lane',
    secondLaneBroken.err.contains('deploy-zzz'),
    secondLaneBroken.err,
  );

  // A lane with NO production selector (dev-only) needs no ref pin, but still
  // needs concurrency. It must not be failed for the pin it does not need.
  final devOnly = runOn({
    'deploy-thing.yml': '''
name: deploy-thing

on:
  workflow_dispatch:

concurrency:
  group: deploy-thing-\${{ github.event.inputs.anything }}
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: echo deploying
''',
  });
  check(
    'selector/no-production-target-needs-no-pin',
    devOnly.code == 0,
    devOnly.err,
  );

  // ---- usage -----------------------------------------------------------------
  final usage = runDeployLaneLint(
    const ['--unexpected'],
    out: StringBuffer(),
    err: StringBuffer(),
  );
  check('usage/rejects-arguments', usage == 64, 'exit $usage');

  if (_failures > 0) {
    stderr.writeln('\ndeploy_lane_lint_test: $_failures FAILED');
    exit(1);
  }
  stdout.writeln('deploy_lane_lint_test: all checks passed');
}
