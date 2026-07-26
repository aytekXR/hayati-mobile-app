// Release-lane lint — fails CI when the release lane's *internal agreement*
// drifts (ADR-032). A credential-free, dependency-free source sentinel over
// `.github/workflows/release.yml`, `fastlane/Fastfile` and
// `fastlane/metadata/*/name.txt`: pure dart:io, runnable in the ubuntu
// quality/preflight jobs before any `pub get`.
//
// WHY this exists, concretely. PR #117 replaced the signing mechanism (App
// Store Connect cloud signing -> fastlane match) and three defects rode along,
// none of which any existing check could see:
//
//   1. `store_metadata` was routed through the match-aware credential helper,
//      so it aborted before `deliver` on every run — inside a step that is
//      `continue-on-error: true` by design, so the job reported SUCCESS. Store
//      metadata has never once been delivered.
//   2. The build got `--build-name=0.1.0` as a LITERAL, so `preflight`'s
//      tag<->pubspec gate began guarding a version string the build ignores.
//   3. The fail-closed secrets gate kept naming the OLD mechanism's secrets, so
//      a missing MATCH_PASSWORD would pass the gate and die inside fastlane —
//      exactly the outcome ADR-021 D4 exists to prevent.
//
// Each rule below is one of those, generalized so the NEXT drift of the same
// shape is caught rather than this one re-caught. Rule 3b is deliberately
// PER STEP: the real defect was invisible at job level, because the job as a
// whole did pass the match inputs — to a different step.
//
// Usage:   dart tool/release_lane_lint.dart
//
// Exit codes: 0 = clean (PASS), 1 = violations (FAIL), 64 = usage/input error
//             (a file this lint reads is missing — a "couldn't check" must
//             never read as green).

import 'dart:io';

// EX_USAGE from sysexits.h: input error, distinct from a real lint FAIL.
const int _exitUsage = 64;

const String _workflowSubpath = '.github/workflows/release.yml';
const String _fastfileSubpath = 'fastlane/Fastfile';
const String _metadataSubpath = 'fastlane/metadata';

/// The App Store listing name, pinned (ADR-032 D6).
///
/// This is a SOURCE SENTINEL, not a style preference. `store_metadata` runs
/// `deliver(force: true)`, which skips the confirmation prompt — so whatever
/// sits in `name.txt` is pushed over the LIVE App Store listing on the next
/// release. The founder renamed the app to "İkimiz" (one of ADR-020 D1's own
/// vetted alternates); the repo still said "Hayati", and only the fact that
/// `store_metadata` was broken kept it from renaming the listing back.
///
/// Changing the store name is a deliberate act with a live consequence. Edit
/// this constant AND every `name.txt` in the same commit, and say why.
const String pinnedStoreName = 'İkimiz';

/// Lane -> the credential helper it MUST call.
///
/// The split is the point (ADR-032 D5): `store_metadata` signs nothing and
/// touches no certificate, so requiring match inputs of it is a bound justified
/// by another caller's constraints — the shape this repo recorded as S042
/// addendum 25.
const Map<String, String> _laneCredentialHelper = {
  'beta': 'ensure_release_credentials!',
  'store_metadata': 'ensure_asc_credentials!',
};

void main(List<String> args) {
  exitCode = runReleaseLaneLint(args, out: stdout, err: stderr);
}

/// In-process entrypoint so the self-tests (`release_lane_lint_test.dart`) can
/// drive the lint against a temp tree without spawning a VM per case.
/// [root] is the repo root; defaults to the current directory.
int runReleaseLaneLint(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  String root = '.',
}) {
  if (args.isNotEmpty) {
    err.writeln('Usage: dart tool/release_lane_lint.dart');
    return _exitUsage;
  }

  final violations = <String>[];
  final passes = <String>[];

  String? read(String subpath) {
    final file = File('$root/$subpath');
    if (file.existsSync()) return file.readAsStringSync();
    err.writeln(
      'release-lane lint: $subpath not found. This lint reads it, so a '
      'missing file is an input error, never a pass.',
    );
    return null;
  }

  final workflow = read(_workflowSubpath);
  final fastfile = read(_fastfileSubpath);
  if (workflow == null || fastfile == null) return _exitUsage;

  violations.addAll(checkNoHardcodedBuildName(fastfile, passes));
  violations.addAll(checkLaneCredentialHelpers(fastfile, passes));
  violations.addAll(checkGateCoversConsumedSecrets(workflow, fastfile, passes));

  final metadataDir = Directory('$root/$_metadataSubpath');
  if (!metadataDir.existsSync()) {
    err.writeln('release-lane lint: $_metadataSubpath not found.');
    return _exitUsage;
  }
  violations.addAll(checkStoreName(metadataDir, passes));

  for (final line in passes) {
    out.writeln('  ok   $line');
  }
  if (violations.isEmpty) {
    out.writeln('release-lane lint: PASS (${passes.length} checks)');
    return 0;
  }
  err.writeln('');
  for (final v in violations) {
    err.writeln('  FAIL $v');
  }
  err.writeln('');
  err.writeln(
    'release-lane lint: ${violations.length} violation(s). See ADR-032.',
  );
  return 1;
}

/// RULE 1 — the Fastfile must not hardcode the build NAME (ADR-032 D3).
///
/// `preflight` hard-fails when a tag's X.Y.Z disagrees with pubspec's, on the
/// stated ground that pubspec is the one source of version truth (ADR-021 D3).
/// A literal `--build-name=` makes that gate vacuous: it still runs, still
/// passes, and guards a string the build does not read. Omitting the flag is
/// what restores it — `flutter build ipa` then reads pubspec, which is what it
/// did before PR #117.
///
/// The build NUMBER is deliberately NOT checked: ADR-032 D3 supersedes
/// ADR-021 D3's build-number clause, and CI synthesizes it on purpose.
List<String> checkNoHardcodedBuildName(String fastfile, List<String> passes) {
  // Scan CODE, not commentary. ADR-032 tells the next reader to delete this
  // flag, so a Fastfile comment explaining its absence is likely — and a lint
  // that reddens on its own remediation note is a lint people delete.
  final matches = RegExp(
    r'--build-name[= ]([^\s"\\]+)',
  ).allMatches(stripRubyComments(fastfile));
  if (matches.isEmpty) {
    passes.add(
      'Fastfile passes no --build-name (pubspec is the version source)',
    );
    return const [];
  }
  return [
    for (final m in matches)
      '$_fastfileSubpath hardcodes --build-name=${m.group(1)}. pubspec.yaml is '
          'the single source of version truth (ADR-021 D3, restored by '
          'ADR-032 D3), and preflight\'s tag<->pubspec gate is VACUOUS while '
          'this is here: tag v0.2.0 against pubspec 0.2.0 passes preflight and '
          'ships a binary stamped ${m.group(1)}. Delete the flag — flutter '
          'reads pubspec.',
  ];
}

/// RULE 2 — each lane calls the credential helper scoped to what it uses
/// (ADR-032 D5).
List<String> checkLaneCredentialHelpers(String fastfile, List<String> passes) {
  final violations = <String>[];
  for (final entry in _laneCredentialHelper.entries) {
    final lane = entry.key;
    final expected = entry.value;
    final body = laneBody(fastfile, lane);
    if (body == null) {
      violations.add(
        '$_fastfileSubpath has no `lane :$lane` block. This lint pins that '
        'lane\'s credential scope, so a renamed or deleted lane must be '
        're-pinned here rather than silently unchecked.',
      );
      continue;
    }
    if (!body.contains(expected)) {
      final found = RegExp(r'ensure_\w+!').firstMatch(body)?.group(0);
      // The rationale is DIRECTION-AWARE. The two mistakes are opposites and a
      // message that explains only one of them argues for the wrong fix — a
      // reader told "a lane that signs nothing must not require signing
      // credentials" about the SIGNING lane would go and weaken its check.
      final tooNarrow = expected == 'ensure_release_credentials!';
      violations.add(
        'lane :$lane must call $expected; found '
        '${found ?? '(no credential helper call)'}. '
        '${tooNarrow ? 'This lane signs and uploads, so it needs the match '
                  'inputs too. With only the ASC check it reaches match() with no '
                  'certificate and fails opaquely, deep in fastlane, instead of at '
                  'the named gate (ADR-021 D4).' : 'A lane that signs nothing must '
                  'not require signing credentials — it aborts before doing its '
                  'job, and because its step is continue-on-error that abort '
                  'renders the job GREEN (ADR-032 D5).'}',
      );
      continue;
    }
    passes.add('lane :$lane calls $expected');
  }
  return violations;
}

/// RULE 3 — the fail-closed gate names every secret the job consumes, and none
/// it does not (ADR-032 D4); RULE 3b — every fastlane step is fed its lane's
/// required inputs.
List<String> checkGateCoversConsumedSecrets(
  String workflow,
  String fastfile,
  List<String> passes,
) {
  final job = signUploadJob(workflow);
  if (job == null) {
    return [
      '$_workflowSubpath has no `sign-upload:` job. This lint pins its gate, '
          'so a rename must be re-pinned here rather than silently unchecked.',
    ];
  }

  // Match the EXPRESSION form `${{ secrets.NAME }}`, never a bare
  // `secrets.NAME`: the job's own comments discuss `secrets.ASC_*`, and a
  // looser pattern reads that prose as a secret named `ASC_` — a lint that
  // invents inputs from commentary would fail the build over a secret nobody
  // can create.
  final secretRef = RegExp(r'\$\{\{\s*secrets\.([A-Z0-9_]+)\s*\}\}');

  final violations = <String>[];
  final gate = gateStep(job);

  // CONSUMPTION IS MEASURED OVER THE WORK STEPS, WITH THE GATE STEP EXCLUDED —
  // and that exclusion is the difference between a real check and a vacuous one.
  //
  // The gate must bind every secret it tests (`X: ${{ secrets.X }}`) or `$X` is
  // empty in its shell and it fails closed on X forever. So the gate's own env
  // block necessarily mentions everything it checks. Measure "consumed" over the
  // WHOLE job and `checked ⊆ consumed` holds unconditionally, by construction:
  // the orphan direction can never fire, and reports a pass that means nothing.
  // Excluding the gate makes "consumed" mean what the name says — what the steps
  // that do the WORK actually read.
  final workSteps = gate == null ? job : job.replaceFirst(gate, '');
  final consumed = secretRef
      .allMatches(workSteps)
      .map((m) => m.group(1)!)
      .toSet();

  if (gate == null) {
    violations.add(
      'the `sign-upload` job has no step named "signing secrets gate". That '
      'step IS the fail-closed boundary (ADR-021 D4); losing it is the '
      'regression this rule exists to catch.',
    );
  } else {
    // The gate tests `[ -n "$NAME" ] || missing+=("NAME")`.
    final checked = RegExp(
      r'missing\+=\("([A-Z0-9_]+)"\)',
    ).allMatches(gate).map((m) => m.group(1)!).toSet();

    final unchecked = consumed.difference(checked).toList()..sort();
    if (unchecked.isNotEmpty) {
      violations.add(
        'the signing secrets gate does not check ${unchecked.join(', ')}, '
        'which the sign-upload job consumes. ADR-021 D4 promises the FIRST '
        'step names the FULL missing set so a partial set never reaches '
        'fastlane; an unchecked secret breaks exactly that promise — it dies '
        'minutes later inside fastlane instead.',
      );
    } else {
      passes.add(
        'the signing secrets gate checks all ${consumed.length} secrets the '
        'sign-upload job consumes',
      );
    }

    final orphaned = checked.difference(consumed).toList()..sort();
    if (orphaned.isNotEmpty) {
      violations.add(
        'the signing secrets gate demands ${orphaned.join(', ')}, which '
        'nothing in the sign-upload job reads. A gate that fails closed on an '
        'unused credential sends the founder after a secret the lane does not '
        'need.',
      );
    } else {
      passes.add('the signing secrets gate demands no secret the job ignores');
    }
  }

  violations.addAll(checkEachLaneStepIsFed(job, fastfile, passes, secretRef));
  return violations;
}

/// RULE 3b — every step invoking a fastlane lane passes that lane's required
/// inputs (ADR-032 D5).
///
/// Checked PER STEP, not per job, and that is the whole point: the defect this
/// catches was GREEN at job level. The job passed MATCH_GIT_URL and
/// MATCH_PASSWORD — to the `beta` step — while the `store_metadata` step, which
/// required them because it called the match-aware helper, received only the
/// three ASC values. It aborted on every release for four days.
List<String> checkEachLaneStepIsFed(
  String job,
  String fastfile,
  List<String> passes,
  RegExp secretRef,
) {
  final helperRequirements = resolveHelperRequirements(fastfile);
  if (helperRequirements.isEmpty) {
    return [
      'no `def ensure_*!` credential helper found in $_fastfileSubpath. The '
          'fail-closed credential check IS that helper (ADR-021 D4); this lint '
          'cannot verify a lane is fed without it.',
    ];
  }

  final violations = <String>[];
  var checkedAny = false;
  for (final step in steps(job)) {
    final invoked = RegExp(
      r'fastlane\s+ios\s+(\w+)',
    ).firstMatch(step)?.group(1);
    if (invoked == null) continue;
    checkedAny = true;

    final body = laneBody(fastfile, invoked);
    final helper = body == null
        ? null
        : RegExp(r'ensure_\w+!').firstMatch(body)?.group(0);
    final required = helper == null ? null : helperRequirements[helper];
    if (required == null) continue;

    final passed = secretRef.allMatches(step).map((m) => m.group(1)!).toSet();
    final starved = required.difference(passed).toList()..sort();
    if (starved.isNotEmpty) {
      violations.add(
        'the step running `fastlane ios $invoked` does not pass '
        '${starved.join(', ')}, which that lane\'s $helper requires. The lane '
        'aborts before doing any work — and if the step is '
        '`continue-on-error: true`, that abort renders the job GREEN '
        '(ADR-032 D5).',
      );
    } else {
      passes.add(
        'the `fastlane ios $invoked` step passes everything $helper needs',
      );
    }
  }
  if (!checkedAny) {
    violations.add(
      'no step in the sign-upload job invokes a fastlane lane. This lint pins '
      'that wiring; a restructured job must be re-pinned here.',
    );
  }
  return violations;
}

/// RULE 4 — the store listing name is pinned, in every locale (ADR-032 D6).
List<String> checkStoreName(Directory metadataDir, List<String> passes) {
  final localeDirs =
      metadataDir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList()
        ..sort();
  if (localeDirs.isEmpty) {
    return ['$_metadataSubpath has no locale directories to check.'];
  }

  final violations = <String>[];
  for (final locale in localeDirs) {
    final subpath = '$_metadataSubpath/$locale/name.txt';
    final file = File('${metadataDir.path}/$locale/name.txt');
    if (!file.existsSync()) {
      violations.add('$subpath is missing.');
      continue;
    }
    final actual = file.readAsStringSync().trim();
    if (actual != pinnedStoreName) {
      violations.add(
        '$subpath is "$actual", pinned "$pinnedStoreName". '
        '`deliver(force: true)` pushes this over the LIVE App Store listing '
        'with no confirmation prompt, so a drifted name.txt RENAMES the '
        'founder\'s app on the next release. Change the pin in '
        'tool/release_lane_lint.dart and every name.txt in one commit '
        '(ADR-032 D6).',
      );
      continue;
    }
    passes.add('$subpath is "$pinnedStoreName"');
  }
  return violations;
}

/// Every `def ensure_*!` helper mapped to the env names it requires,
/// **including the ones it inherits by delegating to another helper**.
///
/// The transitive union matters: `ensure_release_credentials!` delegates the
/// App Store Connect inputs to `ensure_asc_credentials!` and declares only the
/// match inputs itself. A lint that read one `%w[...]` per helper would believe
/// the signing lane needs no ASC key, and rule 3b would go quiet on exactly the
/// starvation it exists to catch. The guard follows the code; the code is not
/// bent to suit the guard.
Map<String, Set<String>> resolveHelperRequirements(String fastfile) {
  final bodies = <String, String>{};
  for (final m in RegExp(
    r'^def (ensure_\w+!)$(.*?)^end',
    multiLine: true,
    dotAll: true,
  ).allMatches(stripRubyComments(fastfile))) {
    bodies[m.group(1)!] = m.group(2)!;
  }

  final resolved = <String, Set<String>>{};
  Set<String> requirementsOf(String helper, Set<String> visiting) {
    final cached = resolved[helper];
    if (cached != null) return cached;
    // A cycle would otherwise recurse forever. Returning empty is safe: the
    // names still arrive through whichever helper in the cycle declares them.
    if (!visiting.add(helper)) return const {};
    final body = bodies[helper];
    if (body == null) return const {};

    final names = <String>{};
    for (final w in RegExp(r'%w\[([^\]]*)\]').allMatches(body)) {
      names.addAll(
        w.group(1)!.split(RegExp(r'\s+')).where((s) => s.isNotEmpty),
      );
    }
    for (final call in RegExp(r'\bensure_\w+!').allMatches(body)) {
      final callee = call.group(0)!;
      if (callee != helper) names.addAll(requirementsOf(callee, visiting));
    }
    visiting.remove(helper);
    resolved[helper] = names;
    return names;
  }

  for (final helper in bodies.keys) {
    requirementsOf(helper, <String>{});
  }
  return resolved;
}

/// Drops whole-line Ruby comments, keeping `#{...}` interpolation intact.
///
/// Only lines whose first non-space character is `#` are removed — a trailing
/// `# ...` on a code line is left alone deliberately, because stripping it
/// naively would also eat the `#` of a `"...#{profile}"` interpolation and
/// silently change what every other rule reads.
String stripRubyComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

/// The body of `lane :<name> do ... end`, delimited by indentation rather than
/// by counting `end`s: lanes sit two spaces inside `platform :ios do`, so the
/// lane ends at the next line that is exactly `  end`.
/// Comments are stripped FIRST, for the same reason rule 1 strips them: a lane
/// whose comment explains which helper it *used* to call would otherwise be
/// read as still calling it. That is not hypothetical — the fix for the
/// store_metadata defect ships with exactly such a comment, and it tripped this
/// lint before the strip was added.
String? laneBody(String rawFastfile, String lane) {
  final fastfile = stripRubyComments(rawFastfile);
  final start = RegExp(
    '^  lane :$lane do\\s*\$',
    multiLine: true,
  ).firstMatch(fastfile);
  if (start == null) return null;
  final rest = fastfile.substring(start.end);
  final end = RegExp(r'^  end\s*$', multiLine: true).firstMatch(rest);
  return end == null ? rest : rest.substring(0, end.start);
}

/// The `sign-upload:` job block, from its key to the next top-level job key.
String? signUploadJob(String workflow) {
  final start = RegExp(
    r'^  sign-upload:\s*$',
    multiLine: true,
  ).firstMatch(workflow);
  if (start == null) return null;
  final rest = workflow.substring(start.end);
  final end = RegExp(
    r'^  [a-z][a-z0-9-]*:\s*$',
    multiLine: true,
  ).firstMatch(rest);
  return end == null ? rest : rest.substring(0, end.start);
}

/// The `signing secrets gate` step, from its `- name:` to the next step.
String? gateStep(String job) {
  final start = RegExp(
    r'^      - name: signing secrets gate\s*$',
    multiLine: true,
  ).firstMatch(job);
  if (start == null) return null;
  final rest = job.substring(start.end);
  final end = RegExp(
    r'^      - (name|uses):',
    multiLine: true,
  ).firstMatch(rest);
  return end == null ? rest : rest.substring(0, end.start);
}

/// The job's steps, split at each `- name:`/`- uses:` at step indentation.
List<String> steps(String job) {
  final starts = RegExp(
    r'^      - (?:name|uses):',
    multiLine: true,
  ).allMatches(job).map((m) => m.start).toList();
  return [
    for (var i = 0; i < starts.length; i++)
      job.substring(
        starts[i],
        i + 1 < starts.length ? starts[i + 1] : job.length,
      ),
  ];
}
