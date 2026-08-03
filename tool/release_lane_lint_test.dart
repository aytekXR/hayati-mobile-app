/// Self-checking tests for the release-lane lint (ADR-032).
///
/// Runner decision (mirrors `store_metadata_lint_test.dart` and
/// `content/validator/validate_test.dart`): `tool/` has no pubspec, so
/// `package:test` cannot run here without inventing one; this is a plain-`dart`
/// self-checking script — every `_check` is an assertion and any failure exits
/// non-zero.
///
/// A guard is only worth what its mutants prove. Every rule is mutation-checked
/// in BOTH directions against a temp tree: the healthy shape must pass, and
/// each drift class must fail with a precise message. The must-stay-GREEN rows
/// are what prove the rules are scoped rather than merely loud — the lesson
/// ADR-029 D3 paid for, where a global-count sentinel would have been green
/// when broken and red when correct.
///
///     dart tool/release_lane_lint_test.dart
library;

import 'dart:io';

import 'release_lane_lint.dart';

var _passed = 0;
final List<String> _failures = [];

void _check(String name, bool condition) {
  if (condition) {
    _passed++;
  } else {
    _failures.add(name);
  }
}

/// A minimal but structurally faithful `release.yml` `sign-upload` job.
///
/// It carries the real shapes the lint parses: the `${{ secrets.X }}`
/// expression form, the gate's `missing+=("NAME")` idiom, per-step `env:`
/// blocks, and a following top-level job key so the job block terminates.
const String _healthyWorkflow = '''
name: release

jobs:
  preflight:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

  sign-upload:
    runs-on: macos-26
    environment: release
    steps:
      - name: signing secrets gate
        env:
          ASC_KEY_ID: \${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: \${{ secrets.ASC_ISSUER_ID }}
          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}
          MATCH_GIT_URL: \${{ secrets.MATCH_GIT_URL }}
          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}
        run: |
          missing=()
          [ -n "\$ASC_KEY_ID" ] || missing+=("ASC_KEY_ID")
          [ -n "\$ASC_ISSUER_ID" ] || missing+=("ASC_ISSUER_ID")
          [ -n "\$ASC_API_KEY_P8_BASE64" ] || missing+=("ASC_API_KEY_P8_BASE64")
          [ -n "\$MATCH_GIT_URL" ] || missing+=("MATCH_GIT_URL")
          [ -n "\$MATCH_PASSWORD" ] || missing+=("MATCH_PASSWORD")
          exit 1
      - name: fastlane beta
        env:
          ASC_KEY_ID: \${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: \${{ secrets.ASC_ISSUER_ID }}
          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}
          MATCH_GIT_URL: \${{ secrets.MATCH_GIT_URL }}
          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}
        run: bundle exec fastlane ios beta
      - name: fastlane store_metadata
        continue-on-error: true
        env:
          ASC_KEY_ID: \${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: \${{ secrets.ASC_ISSUER_ID }}
          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}
        run: bundle exec fastlane ios store_metadata

  slack-notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
''';

/// A minimal but structurally faithful `Fastfile`: two helpers with different
/// `%w[...]` requirement sets, and two lanes calling the right one each.
const String _healthyFastfile = r'''
default_platform(:ios)

def ensure_asc_credentials!
  required = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_API_KEY_P8_BASE64]
  missing = required.select { |key| (ENV[key] || "").strip.empty? }
  return if missing.empty?
  UI.user_error!("missing #{missing.join(', ')}")
end

def ensure_release_credentials!
  required = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_API_KEY_P8_BASE64 MATCH_GIT_URL MATCH_PASSWORD]
  missing = required.select { |key| (ENV[key] || "").strip.empty? }
  return if missing.empty?
  UI.user_error!("missing #{missing.join(', ')}")
end

platform :ios do
  lane :beta do
    ensure_release_credentials!
    build_number = 100 + ENV.fetch("GITHUB_RUN_NUMBER", "1").to_i
    sh("cd ../app && flutter build ipa --release -t lib/main_prod.dart " \
       "--build-number=#{build_number} " \
       "--export-options-plist ios/ExportOptions.plist")
  end

  lane :store_metadata do
    ensure_asc_credentials!
    deliver(skip_binary_upload: true, force: true)
  end

  # Present because `_laneCredentialHelper` is an ALLOW-LIST and RULE 2 treats
  # a mapped lane with no block as a violation — so a lane added to the map
  # without being added here turns every should-pass fixture red at once,
  # which is how this arrived. (Ruby comments: this string is a Fastfile.)
  lane :store_screenshots do
    ensure_asc_credentials!
    deliver(skip_binary_upload: true, skip_metadata: true, force: true)
  end
end
''';

void _writeTree(
  String root, {
  String? workflow,
  String? fastfile,
  Map<String, String>? names,
}) {
  final wfDir = Directory('$root/.github/workflows')
    ..createSync(recursive: true);
  if (workflow != null) {
    File('${wfDir.path}/release.yml').writeAsStringSync(workflow);
  }
  final fastlaneDir = Directory('$root/fastlane')..createSync(recursive: true);
  if (fastfile != null) {
    File('${fastlaneDir.path}/Fastfile').writeAsStringSync(fastfile);
  }
  final locales = names ?? {'en-US': pinnedStoreName, 'tr': pinnedStoreName};
  for (final entry in locales.entries) {
    final dir = Directory('$root/fastlane/metadata/${entry.key}')
      ..createSync(recursive: true);
    File('${dir.path}/name.txt').writeAsStringSync(entry.value);
  }
  if (locales.isEmpty) {
    Directory('$root/fastlane/metadata').createSync(recursive: true);
  }
}

(int, String, String) _run(String root, {List<String> args = const []}) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runReleaseLaneLint(args, out: out, err: err, root: root);
  return (code, out.toString(), err.toString());
}

/// Builds a fresh temp root, applies [mutate] to the healthy fixtures, runs the
/// lint, and returns the result.
(int, String, String) _mutant({
  String? workflow,
  String? fastfile,
  Map<String, String>? names,
}) {
  final temp = Directory.systemTemp.createTempSync('hayati_release_lane_lint');
  try {
    _writeTree(
      temp.path,
      workflow: workflow ?? _healthyWorkflow,
      fastfile: fastfile ?? _healthyFastfile,
      names: names,
    );
    // Rule 5 reads these; without them every other rule's mutant would exit 64
    // as an input error and the assertions below would test nothing.
    File('${temp.path}/Gemfile').writeAsStringSync(_healthyGemfile);
    File('${temp.path}/Gemfile.lock').writeAsStringSync(_lockWith('2.237.0'));
    return _run(temp.path);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// A `Gemfile.lock` whose only interesting line is the resolved fastlane version.
String _lockWith(String version) =>
    'GEM\n  remote: https://rubygems.org/\n  specs:\n'
    '    fastlane ($version)\n\nPLATFORMS\n  arm64-darwin-23\n  ruby\n\n'
    'DEPENDENCIES\n  fastlane (~> 2.225)\n\nBUNDLED WITH\n   2.5.22\n';

const String _healthyGemfile =
    'source "https://rubygems.org"\n\ngem "fastlane", "~> 2.225"\n';

/// Like [_mutant], but also writes a Gemfile and (unless [lock] is explicitly
/// null) a Gemfile.lock, so rule 5 has something to read. Passing `lock: null`
/// is the missing-lock case.
(int, String, String) _mutantWithGems({
  String? workflow,
  String? fastfile,
  Map<String, String>? names,
  String? gemfile,
  Object? lock = _sentinel,
}) {
  final temp = Directory.systemTemp.createTempSync('hayati_rll_gems');
  try {
    _writeTree(
      temp.path,
      workflow: workflow ?? _healthyWorkflow,
      fastfile: fastfile ?? _healthyFastfile,
      names: names,
    );
    File('${temp.path}/Gemfile').writeAsStringSync(gemfile ?? _healthyGemfile);
    final lockBody = identical(lock, _sentinel) ? _lockWith('2.237.0') : lock;
    if (lockBody != null) {
      File('${temp.path}/Gemfile.lock').writeAsStringSync(lockBody as String);
    }
    return _run(temp.path);
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// Writes the healthy Gemfile + lock. Raw-temp-tree cases need this explicitly:
/// without it rule 5 reports an INPUT error (exit 64) and whichever rule the case
/// was written to exercise is never reached — the assertion would pass or fail
/// for the wrong reason.
void _writeGems(String root) {
  File('$root/Gemfile').writeAsStringSync(_healthyGemfile);
  File('$root/Gemfile.lock').writeAsStringSync(_lockWith('2.237.0'));
}

/// Distinguishes "caller did not pass lock" from "caller passed null on purpose".
const Object _sentinel = Object();

void main() {
  // ---------------------------------------------------------------- GREEN ---
  // The healthy shape must pass. Without this row every mutant below could be
  // failing for a reason that has nothing to do with the mutation.
  {
    final (code, out, err) = _mutant();
    _check('healthy fixtures pass', code == 0);
    _check('healthy run reports PASS', out.contains('release-lane lint: PASS'));
    _check('healthy run writes no violations', !err.contains('FAIL'));
  }

  // MUST STAY GREEN: a Fastfile COMMENT mentioning --build-name is not a
  // hardcoded build name. ADR-032 tells the next reader to delete that flag, so
  // a comment explaining its absence is the likeliest future edit — a lint that
  // reddens on its own remediation note is a lint people delete.
  {
    final commented = _healthyFastfile.replaceFirst(
      'platform :ios do',
      '# Deliberately no --build-name=0.1.0 here: pubspec is the source of\n'
          '# version truth (ADR-032 D3).\nplatform :ios do',
    );
    final (code, _, err) = _mutant(fastfile: commented);
    _check('a --build-name mention in a COMMENT stays green', code == 0);
    _check('...and names no build-name violation', !err.contains('build-name'));
  }

  // MUST STAY GREEN: the lint reads `${{ secrets.X }}`, not prose. The real
  // release.yml discusses `secrets.ASC_*` in a comment; a looser matcher would
  // invent a consumed secret named `ASC_` and fail the build over a secret
  // nobody can create.
  {
    final chatty = _healthyWorkflow.replaceFirst(
      '  sign-upload:',
      '  # Without the environment binding, secrets.ASC_* resolves empty.\n'
          '  sign-upload:',
    );
    final (code, _, err) = _mutant(workflow: chatty);
    _check('a bare secrets.ASC_* in a comment stays green', code == 0);
    _check('...and no phantom ASC_ secret is reported', !err.contains('ASC_,'));
  }

  // MUST STAY GREEN: a lane whose COMMENT names the helper it used to call is
  // still correct. Not hypothetical — the store_metadata fix ships with exactly
  // that comment, and it tripped rule 3b before laneBody stripped comments.
  {
    final commented = _healthyFastfile.replaceFirst(
      '    ensure_asc_credentials!\n    deliver',
      '    # Was ensure_release_credentials! until S047; this lane signs\n'
          '    # nothing (ADR-032 D5).\n'
          '    ensure_asc_credentials!\n    deliver',
    );
    final (code, _, err) = _mutant(fastfile: commented);
    _check('a lane comment naming the OLD helper stays green', code == 0);
    _check(
      '...and no phantom starvation is reported',
      !err.contains('fastlane ios store_metadata'),
    );
  }

  // ------------------------------------------------------ RULE 1 mutants ---
  {
    final (code, _, err) = _mutant(
      fastfile: _healthyFastfile.replaceFirst(
        '--build-number=',
        '--build-name=9.9.9 --build-number=',
      ),
    );
    _check('R1: a hardcoded --build-name fails', code == 1);
    _check('R1: names the offending value', err.contains('9.9.9'));
    _check('R1: names pubspec as the source', err.contains('pubspec.yaml'));
  }

  // ------------------------------------------------------ RULE 2 mutants ---
  {
    // THE production defect: store_metadata routed through the match-aware
    // helper. It aborts before deliver, inside a continue-on-error step.
    final (code, _, err) = _mutant(
      fastfile: _healthyFastfile.replaceFirst(
        '    ensure_asc_credentials!\n    deliver',
        '    ensure_release_credentials!\n    deliver',
      ),
    );
    _check('R2: store_metadata on the match helper fails', code == 1);
    _check(
      'R2: names the expected helper',
      err.contains('must call ensure_asc_credentials!'),
    );
    // and Rule 3b independently catches the same defect from the other side
    _check(
      'R3b: the starved store_metadata step is also reported',
      err.contains('fastlane ios store_metadata') &&
          err.contains('MATCH_GIT_URL'),
    );
  }
  {
    final (code, _, err) = _mutant(
      fastfile: _healthyFastfile.replaceFirst(
        '    ensure_asc_credentials!\n',
        '',
      ),
    );
    _check('R2: a lane with NO credential helper fails', code == 1);
    _check(
      'R2: says no helper was called',
      err.contains('no credential helper'),
    );
  }
  {
    final (code, _, err) = _mutant(
      fastfile: _healthyFastfile.replaceFirst('lane :beta do', 'lane :ship do'),
    );
    _check('R2: a renamed pinned lane fails', code == 1);
    _check('R2: names the missing lane', err.contains('no `lane :beta` block'));
  }

  // ------------------------------------------------------ RULE 3 mutants ---
  {
    // The gate stops checking a secret the job still consumes — the ADR-021 D4
    // guarantee silently narrowing, which is exactly what PR #117 did.
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '          [ -n "\$MATCH_PASSWORD" ] || missing+=("MATCH_PASSWORD")\n',
        '',
      ),
    );
    _check('R3: an unchecked consumed secret fails', code == 1);
    _check('R3: names it', err.contains('does not check MATCH_PASSWORD'));
  }
  {
    // The inverse: the gate demands a credential nothing reads, sending the
    // founder after a secret the lane does not need.
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '          exit 1',
        '          [ -n "\$ASC_LEGACY_P8" ] || missing+=("ASC_LEGACY_P8")\n'
            '          exit 1',
      ),
    );
    _check('R3: an orphaned gate demand fails', code == 1);
    _check('R3: names it', err.contains('demands ASC_LEGACY_P8'));
  }
  {
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '      - name: signing secrets gate',
        '      - name: setup',
      ),
    );
    _check('R3: deleting the gate step fails', code == 1);
    _check(
      'R3: says the boundary is gone',
      err.contains('no step named "signing secrets gate"'),
    );
  }
  {
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '  sign-upload:',
        '  sign_upload:',
      ),
    );
    _check('R3: a renamed sign-upload job fails', code == 1);
    _check('R3: names the missing job', err.contains('no `sign-upload:` job'));
  }

  // ------------------------------------- RULE 3's gate exemption (ADR-038) ---
  //
  // Three rows, because an allow-list you cannot mutate is an allow-list that
  // proves nothing. The MUST-STAY-GREEN row is the one that makes the other two
  // mean something: it is what distinguishes a real exemption from a rule that
  // was simply switched off.
  {
    // MUST STAY GREEN. A gate-exempt secret read by a continue-on-error step is
    // the ADR-038 D4 shape and must NOT fail — the Test Information write is
    // deliberately survivable, and demanding it in the gate would abort the
    // release before the build assignment (repealing ADR-037 silently).
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '        run: bundle exec fastlane ios store_metadata',
        '        run: bundle exec fastlane ios store_metadata\n'
            '      - name: assign to Friends\n'
            '        continue-on-error: true\n'
            '        env:\n'
            '          ASC_KEY_ID: \${{ secrets.ASC_KEY_ID }}\n'
            '          ASC_ISSUER_ID: \${{ secrets.ASC_ISSUER_ID }}\n'
            '          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}\n'
            '          ASC_REVIEW_CONTACT_FIRST_NAME: \${{ secrets.ASC_REVIEW_CONTACT_FIRST_NAME }}\n'
            '          ASC_REVIEW_CONTACT_PHONE: \${{ secrets.ASC_REVIEW_CONTACT_PHONE }}\n'
            '        run: python3 tool/ci/testflight_testers.py --set-review-contact',
      ),
    );
    _check(
      'R3x: an exempt secret in a continue-on-error step PASSES',
      code == 0,
    );
    _check(
      'R3x: and the gate is not reported as incomplete',
      !err.contains('does not check ASC_REVIEW_CONTACT'),
    );
  }
  {
    // The exemption's premise, falsified: the same secret in a step whose
    // failure is NOT survivable. Then "its absence is fine" is simply untrue and
    // the gate's promise really has been broken.
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '        run: bundle exec fastlane ios store_metadata',
        '        run: bundle exec fastlane ios store_metadata\n'
            '      - name: assign to Friends\n'
            '        env:\n'
            '          ASC_REVIEW_CONTACT_PHONE: \${{ secrets.ASC_REVIEW_CONTACT_PHONE }}\n'
            '        run: python3 tool/ci/testflight_testers.py --set-review-contact',
      ),
    );
    _check('R3x: an exempt secret in a BLOCKING step fails', code == 1);
    _check(
      'R3x: and says the exemption or the step is wrong',
      err.contains('ASC_REVIEW_CONTACT_PHONE') &&
          err.contains('not survivable'),
    );
  }
  {
    // A secret that is NOT on the exemption list still has to be gated — the
    // allow-list must not have widened into "anything in a soft step is fine".
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '        run: bundle exec fastlane ios store_metadata',
        '        run: bundle exec fastlane ios store_metadata\n'
            '      - name: extra\n'
            '        continue-on-error: true\n'
            '        env:\n'
            '          SOME_OTHER_SECRET: \${{ secrets.SOME_OTHER_SECRET }}\n'
            '        run: echo hi',
      ),
    );
    _check('R3x: a non-exempt secret is still gated', code == 1);
    _check('R3x: names it', err.contains('does not check SOME_OTHER_SECRET'));
  }

  {
    // THE ORPHAN DIRECTION, made real. `consumed` is measured with the GATE STEP
    // EXCLUDED. Measured over the whole job it was vacuous by construction: the
    // gate must bind every secret it tests, so `checked ⊆ consumed` always held
    // and this branch could never fire. Here the work step that reads MATCH_* is
    // deleted while the gate keeps demanding them — the realistic shape (a lane
    // narrowed, its gate not) that the old version reported as clean.
    final betaRemoved = _healthyWorkflow.replaceFirst(
      '''      - name: fastlane beta
        env:
          ASC_KEY_ID: \${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: \${{ secrets.ASC_ISSUER_ID }}
          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}
          MATCH_GIT_URL: \${{ secrets.MATCH_GIT_URL }}
          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}
        run: bundle exec fastlane ios beta
''',
      '',
    );
    final (code, _, err) = _mutant(workflow: betaRemoved);
    _check('R3: a gate demand no WORK step reads is orphaned', code == 1);
    _check(
      'R3: names both newly-unread secrets',
      err.contains('demands MATCH_GIT_URL, MATCH_PASSWORD'),
    );
  }
  {
    // F2's row: ASC_ISSUER_ID is what `app_store_connect_api_key(issuer_id:)`
    // dies on, and until this row existed no mutant removed it from a step.
    final noIssuer = _healthyWorkflow.replaceFirst(
      '''          ASC_ISSUER_ID: \${{ secrets.ASC_ISSUER_ID }}
          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}
        run: bundle exec fastlane ios store_metadata''',
      '''          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}
        run: bundle exec fastlane ios store_metadata''',
    );
    final (code, _, err) = _mutant(workflow: noIssuer);
    _check('R3b: a store_metadata step missing ASC_ISSUER_ID fails', code == 1);
    _check(
      'R3b: names the step and ASC_ISSUER_ID',
      err.contains('fastlane ios store_metadata') &&
          err.contains('ASC_ISSUER_ID'),
    );
  }
  {
    // The INVERSE of the store_metadata defect: the signing lane narrowed to the
    // ASC-only helper. The rule must fire AND must not explain it with the
    // opposite lane's rationale — a message telling someone that "a lane that
    // signs nothing must not require signing credentials", about the lane that
    // signs, argues for exactly the wrong fix.
    final (code, _, err) = _mutant(
      fastfile: _healthyFastfile.replaceFirst(
        '    ensure_release_credentials!\n    build_number',
        '    ensure_asc_credentials!\n    build_number',
      ),
    );
    _check('R2: the SIGNING lane on the narrow helper fails', code == 1);
    _check(
      'R2: explains it as a signing lane, not a non-signing one',
      err.contains('This lane signs and uploads') &&
          !err.contains('A lane that signs nothing must not require'),
    );
  }

  // ----------------------------------------------------- RULE 3b mutants ---
  {
    // A step starved of an input its lane requires — job-level checking is
    // GREEN here, which is the entire reason this rule is per-step.
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceFirst(
        '          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}\n'
            '        run: bundle exec fastlane ios beta',
        '        run: bundle exec fastlane ios beta',
      ),
    );
    _check('R3b: a starved fastlane step fails', code == 1);
    _check(
      'R3b: names the step and the input',
      err.contains('fastlane ios beta') && err.contains('MATCH_PASSWORD'),
    );
  }
  {
    final (code, _, err) = _mutant(
      fastfile: _healthyFastfile
          .replaceAll('def ensure_asc_credentials!', 'def check_asc')
          .replaceAll('def ensure_release_credentials!', 'def check_release')
          .replaceAll('ensure_asc_credentials!', 'check_asc')
          .replaceAll('ensure_release_credentials!', 'check_release'),
    );
    _check('R3b: no ensure_*! helper at all fails', code == 1);
  }
  {
    final (code, _, err) = _mutant(
      workflow: _healthyWorkflow.replaceAll(
        'bundle exec fastlane ios',
        'echo skip',
      ),
    );
    _check('R3b: a job invoking no fastlane lane fails', code == 1);
    _check(
      'R3b: says the wiring is gone',
      err.contains('no step in the sign-upload job invokes a fastlane lane'),
    );
  }

  // ------------------------------------ RULE 3b: transitive requirements ---
  // The shipped Fastfile DELEGATES: ensure_release_credentials! calls
  // ensure_asc_credentials! and declares only the match inputs itself. A lint
  // reading one %w[...] per helper would conclude the signing lane needs no ASC
  // key at all — and would go quiet on exactly the starvation rule 3b exists to
  // catch. These two rows are the mutation check for that resolution.
  {
    final delegating = _healthyFastfile.replaceFirst(
      '  required = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_API_KEY_P8_BASE64 MATCH_GIT_URL MATCH_PASSWORD]',
      '  ensure_asc_credentials!\n  required = %w[MATCH_GIT_URL MATCH_PASSWORD]',
    );

    // Healthy + delegating still passes: delegation is not itself a defect.
    final (okCode, _, _) = _mutant(fastfile: delegating);
    _check('R3b: a DELEGATING helper chain stays green when fed', okCode == 0);

    // Now starve the beta step of an input it inherits ONLY through the
    // delegate. Pre-resolution this was invisible.
    final starvedWorkflow = _healthyWorkflow.replaceFirst(
      '          ASC_KEY_ID: \${{ secrets.ASC_KEY_ID }}\n'
          '          ASC_ISSUER_ID: \${{ secrets.ASC_ISSUER_ID }}\n'
          '          ASC_API_KEY_P8_BASE64: \${{ secrets.ASC_API_KEY_P8_BASE64 }}\n'
          '          MATCH_GIT_URL: \${{ secrets.MATCH_GIT_URL }}\n'
          '          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}\n'
          '        run: bundle exec fastlane ios beta',
      '          MATCH_GIT_URL: \${{ secrets.MATCH_GIT_URL }}\n'
          '          MATCH_PASSWORD: \${{ secrets.MATCH_PASSWORD }}\n'
          '        run: bundle exec fastlane ios beta',
    );
    final (code, _, err) = _mutant(
      workflow: starvedWorkflow,
      fastfile: delegating,
    );
    _check('R3b: an INHERITED requirement is enforced', code == 1);
    _check(
      'R3b: names the inherited input',
      err.contains('fastlane ios beta') && err.contains('ASC_KEY_ID'),
    );
  }
  {
    // A delegation cycle must not hang the lint. It is nonsense Ruby, but a
    // guard that spins forever on malformed input is worse than one that fails.
    final cyclic = _healthyFastfile.replaceFirst(
      'def ensure_asc_credentials!\n  required = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_API_KEY_P8_BASE64]',
      'def ensure_asc_credentials!\n  ensure_release_credentials!\n'
          '  required = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_API_KEY_P8_BASE64]',
    );
    final (code, _, _) = _mutant(fastfile: cyclic);
    _check('R3b: a helper delegation CYCLE terminates', code == 0 || code == 1);
  }

  // ------------------------------------------------------ RULE 4 mutants ---
  {
    final (code, _, err) = _mutant(
      names: {'en-US': 'Hayati', 'tr': pinnedStoreName},
    );
    _check('R4: a drifted store name fails', code == 1);
    _check(
      'R4: names the file and both values',
      err.contains('en-US/name.txt'),
    );
    _check('R4: warns it renames the LIVE listing', err.contains('RENAMES'));
    _check(
      'R4: the healthy locale is not flagged',
      !err.contains('tr/name.txt'),
    );
  }
  {
    // Every locale is checked, not just the first: a rule that stopped early
    // would pass a tree whose second locale had drifted.
    final (code, _, err) = _mutant(
      names: {'en-US': pinnedStoreName, 'tr': 'Hayati'},
    );
    _check('R4: drift in the SECOND locale also fails', code == 1);
    _check('R4: names the second locale', err.contains('tr/name.txt'));
  }
  {
    final temp = Directory.systemTemp.createTempSync('hayati_rll_noname');
    try {
      _writeTree(
        temp.path,
        workflow: _healthyWorkflow,
        fastfile: _healthyFastfile,
        names: const {},
      );
      _writeGems(temp.path);
      Directory('${temp.path}/fastlane/metadata').createSync(recursive: true);
      final (code, _, err) = _run(temp.path);
      _check('R4: a metadata dir with no locales fails', code == 1);
      _check('R4: says so', err.contains('no locale directories'));
    } finally {
      temp.deleteSync(recursive: true);
    }
  }
  {
    final temp = Directory.systemTemp.createTempSync('hayati_rll_missingname');
    try {
      _writeTree(
        temp.path,
        workflow: _healthyWorkflow,
        fastfile: _healthyFastfile,
      );
      _writeGems(temp.path);
      File('${temp.path}/fastlane/metadata/tr/name.txt').deleteSync();
      final (code, _, err) = _run(temp.path);
      _check('R4: a missing name.txt fails', code == 1);
      _check(
        'R4: names the missing file',
        err.contains('tr/name.txt is missing'),
      );
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  // ------------------------------------------------------ RULE 5 mutants ---
  // Gemfile.lock presence + agreement with the Gemfile (issue #120).
  {
    final (code, out, _) = _mutantWithGems();
    _check('R5: a satisfying lock passes', code == 0);
    _check(
      'R5: names the resolved version and the constraint',
      out.contains('fastlane 2.237.0') && out.contains('~> 2.225'),
    );
  }
  {
    // THE defect this rule exists for: no lock, so every release resolves fresh.
    final (code, _, err) = _mutantWithGems(lock: null);
    _check('R5: a MISSING lock fails', code == 1);
    _check('R5: says it is missing', err.contains('Gemfile.lock is MISSING'));
    _check(
      'R5: tells the reader how to regenerate it',
      err.contains('gh workflow run gemfile-lock.yml'),
    );
  }
  {
    final (code, _, err) = _mutantWithGems(lock: _lockWith('2.224.0'));
    _check('R5: a lock BELOW the constraint floor fails', code == 1);
    _check('R5: names both versions', err.contains('2.224.0'));
  }
  {
    // The boundary that matters most: `~> 2.225` must NOT admit 3.x. Getting the
    // pessimistic upper bound backwards would silently accept a major bump —
    // precisely the change a lock exists to catch.
    final (code, _, err) = _mutantWithGems(lock: _lockWith('3.0.0'));
    _check('R5: a MAJOR bump is rejected by "~> 2.225"', code == 1);
    _check('R5: names the offending version', err.contains('3.0.0'));
  }
  {
    // MUST STAY GREEN: a minor/patch bump inside the range is exactly what the
    // constraint is for. A rule that reddened here would be a freeze, not a pin,
    // and would be relaxed within a week.
    final (code, _, _) = _mutantWithGems(lock: _lockWith('2.299.13'));
    _check('R5: a bump INSIDE the range stays green', code == 0);
  }
  {
    // The Gemfile moved and the lock did not — `bundle install` would fail
    // inside the release job, past a 40-minute macOS leg.
    final (code, _, err) = _mutantWithGems(
      gemfile: 'source "https://rubygems.org"\ngem "fastlane", "~> 2.240"\n',
    );
    _check('R5: a Gemfile bump without a lock regen fails', code == 1);
    _check('R5: names the disagreement', err.contains('does NOT satisfy'));
  }
  {
    final (code, _, err) = _mutantWithGems(
      lock: 'GEM\n  specs:\n    commander (4.6.0)\n\nPLATFORMS\n  ruby\n',
    );
    _check('R5: a lock with no fastlane spec line fails', code == 1);
    _check(
      'R5: says a lock without its gem is not a lock',
      err.contains('no resolved `fastlane'),
    );
  }
  {
    // A three-segment constraint tightens the upper bound to the MINOR: this is
    // the other half of the pessimistic operator, and the two must not be
    // conflated.
    final (code, _, _) = _mutantWithGems(
      gemfile: 'source "https://rubygems.org"\ngem "fastlane", "~> 2.225.1"\n',
      lock: _lockWith('2.225.9'),
    );
    _check('R5: "~> 2.225.1" admits 2.225.9', code == 0);
    final (code2, _, _) = _mutantWithGems(
      gemfile: 'source "https://rubygems.org"\ngem "fastlane", "~> 2.225.1"\n',
      lock: _lockWith('2.226.0'),
    );
    _check('R5: "~> 2.225.1" REJECTS 2.226.0', code2 == 1);
  }
  {
    final (code, _, _) = _mutantWithGems(
      gemfile: 'source "https://rubygems.org"\ngem "fastlane"\n',
    );
    _check(
      'R5: a Gemfile with no ~> constraint fails (not vacuous)',
      code == 1,
    );
  }
  {
    // MUST STAY GREEN: the real Gemfile carries a long comment block that
    // mentions `bundle install --frozen` and issue #120. Commentary is not a
    // constraint declaration, and the rule reads code.
    final (code, _, _) = _mutantWithGems(
      gemfile:
          '# gem "fastlane", "~> 9.9" would be wrong; see #120.\n'
          'source "https://rubygems.org"\n'
          'gem "fastlane", "~> 2.225"\n',
    );
    _check('R5: a commented-out constraint is ignored', code == 0);
  }

  // ------------------------------------------- input errors are NOT green ---
  // A lint that cannot read its inputs must exit 64, never 0. "Couldn't check"
  // reading as "checked and fine" is the failure mode every guard in this repo
  // is written against.
  {
    final temp = Directory.systemTemp.createTempSync('hayati_rll_noworkflow');
    try {
      _writeTree(temp.path, fastfile: _healthyFastfile);
      final (code, _, _) = _run(temp.path);
      _check('a missing release.yml exits 64, not 0', code == 64);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }
  {
    final temp = Directory.systemTemp.createTempSync('hayati_rll_nofastfile');
    try {
      _writeTree(temp.path, workflow: _healthyWorkflow);
      final (code, _, _) = _run(temp.path);
      _check('a missing Fastfile exits 64, not 0', code == 64);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }
  {
    final temp = Directory.systemTemp.createTempSync('hayati_rll_nometa');
    try {
      Directory('${temp.path}/.github/workflows').createSync(recursive: true);
      File(
        '${temp.path}/.github/workflows/release.yml',
      ).writeAsStringSync(_healthyWorkflow);
      Directory('${temp.path}/fastlane').createSync(recursive: true);
      File(
        '${temp.path}/fastlane/Fastfile',
      ).writeAsStringSync(_healthyFastfile);
      final (code, _, _) = _run(temp.path);
      _check('a missing metadata dir exits 64, not 0', code == 64);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }
  {
    final temp = Directory.systemTemp.createTempSync('hayati_rll_args');
    try {
      _writeTree(
        temp.path,
        workflow: _healthyWorkflow,
        fastfile: _healthyFastfile,
      );
      final (code, _, _) = _run(temp.path, args: ['--unexpected']);
      _check('an unexpected argument exits 64', code == 64);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  if (_failures.isEmpty) {
    stdout.writeln('release_lane_lint self-tests: $_passed checks passed');
  } else {
    stderr.writeln(
      'release_lane_lint self-tests: ${_failures.length} FAILED, '
      '$_passed passed',
    );
    for (final name in _failures) {
      stderr.writeln('  FAIL: $name');
    }
    exitCode = 1;
  }
}
