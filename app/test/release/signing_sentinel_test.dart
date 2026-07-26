import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-SENTINEL over the iOS project's **signing** settings (ADR-029 D3).
///
/// WHY this shape: nothing in the per-PR merge gate can see a signing
/// regression. `flutter analyze` and `flutter test` never read the pbxproj;
/// `ci.yml`'s `ios-build-smoke` builds with `--no-codesign`, so signing is
/// *disabled* there and the job is structurally incapable of noticing that
/// signing is broken; and `release.yml` runs only on a `v*.*.*` tag or a manual
/// dispatch. So between two releases a signing setting can be deleted by one
/// Xcode click and **every required check stays green** — the failure would
/// surface weeks later as a red release lane, on the day someone wants to ship.
///
/// This is the `device_privacy_channel_parity_test.dart` motivation applied to
/// a second invisible surface, but deliberately **NOT** that test's mechanism.
/// It counts `allMatches` over the WHOLE FILE, which is sound for its own key
/// (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` occurs only in app-target
/// blocks, so the global count IS the app-target count). `CODE_SIGN_STYLE =
/// Automatic` is the exact inverse: it already occurred 3x in **RunnerTests**
/// and 0x in Runner, so a global `expect(count, 3)` would be green when broken,
/// red when correct, and green again when re-broken. That was the blocking
/// finding of ADR-029's pre-code review. Hence: parse per
/// `XCBuildConfiguration` block and classify each block by the
/// `PRODUCT_BUNDLE_IDENTIFIER` **inside that block** — identify the target by
/// what it IS, never by a UUID Xcode could regenerate.
///
/// BOUND, recorded: this proves the settings are present and correctly valued.
/// It cannot prove Apple ACCEPTS them — only a real release-lane run does.
void main() {
  const pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';

  /// The founder's Apple Developer Team ID. An identifier, not a credential —
  /// it is published in every distributed IPA's embedded provisioning profile
  /// and already appears in four repo documents (ADR-029 D1).
  const teamId = 'UH7MXG7Z94';
  const appBundleId = 'com.beyondkaira.hayati';
  const testsBundleId = 'com.beyondkaira.hayati.RunnerTests';

  late List<_BuildConfig> configs;

  setUpAll(() {
    final file = File(pbxprojPath);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the sentinel must fail loudly if $pbxprojPath is moved or renamed, '
          'rather than pass vacuously — re-point it and KEEP the pin',
    );
    configs = _parseBuildConfigs(file.readAsStringSync());

    // Guard the PARSER itself. If Xcode ever rewrites the file in a shape this
    // regex does not match, every scoped assertion below would pass over an
    // empty set — a vacuous green that reads exactly like a real one.
    // EXACT, not >=: a lower bound catches only an under-matching parser. An
    // over-matching one (a regex bug yielding spurious blocks) would slip
    // through a `>= 9`, and the downstream assertions would only notice by
    // luck. 9 = 3 project-level + 3 RunnerTests + 3 Runner app-target.
    expect(
      configs.length,
      9,
      reason:
          'parsed ${configs.length} XCBuildConfiguration blocks, expected 9 '
          '(3 project-level + 3 RunnerTests + 3 app-target). The parser has '
          'either lost blocks — making every scoped assertion below vacuous — '
          'or picked up spurious ones. If Xcode legitimately added a target or '
          'a configuration, that is a signing-surface change a human should '
          'confirm: update this census WITH the pbxproj. Never relax it to a '
          'lower bound.',
    );
  });

  List<_BuildConfig> appTargets() =>
      configs.where((c) => c.bundleId == appBundleId).toList();

  test('the app target has exactly THREE build configs, and so do the tests', () {
    // A deleted, added, or renamed configuration is a defect, not churn: the
    // three are Debug (local + cable rig), Release (`flutter build ipa`), and
    // Profile (`--profile`). A setting present in one and absent in another is
    // a trap that fires on whichever path is used next.
    expect(
      appTargets().map((c) => c.name).toList()..sort(),
      ['Debug', 'Profile', 'Release'],
      reason:
          'expected exactly the three app-target configs carrying '
          '$appBundleId; found ${appTargets().map((c) => '${c.name}/${c.id}').toList()}',
    );
    expect(
      configs.where((c) => c.bundleId == testsBundleId).length,
      3,
      reason: 'the RunnerTests target must keep its three configs too',
    );
  });

  test('EVERY app-target config carries the DEVELOPMENT_TEAM', () {
    // Without this, `xcodebuild` archive fails with "Signing for 'Runner'
    // requires a development team" — the exact failure ADR-021 D5 predicted
    // and the whole reason ADR-029 exists.
    for (final c in appTargets()) {
      expect(
        c.settings['DEVELOPMENT_TEAM'],
        teamId,
        reason:
            'app-target config ${c.name} (${c.id}) must carry '
            'DEVELOPMENT_TEAM = $teamId; found '
            '${c.settings['DEVELOPMENT_TEAM'] ?? '(absent)'}',
      );
    }
  });

  test('EVERY app-target config pins CODE_SIGN_STYLE = Automatic', () {
    // The pin STANDS; its reason INVERTED, and the old one is worth stating so
    // the next reader is not misled by a stale justification (ADR-032 D7).
    //
    // ADR-029 D2 pinned this because ADR-021 D5's cloud-signing mechanism —
    // `-allowProvisioningUpdates` plus the API key at xcodebuild's
    // ~/.appstoreconnect/private_keys auto-discovery path — is INERT under
    // manual signing, so a one-word flip here silently invalidated that ADR.
    //
    // Since ADR-032 the release lane signs MANUALLY on purpose: fastlane
    // `match` installs the stored certificate + profile and
    // `update_code_signing_settings(use_automatic_signing: false)` writes
    // `Manual` into the CHECKED-OUT pbxproj before archiving. The lane now
    // performs, deliberately and every run, the exact flip this test was first
    // written to catch.
    //
    // So what this pin defends is no longer the release path. It is (a) the
    // founder's Mac and the cable rig, which build the COMMITTED project with
    // Xcode automatic signing, and (b) a known starting state for the CI
    // mutation. Both are real, and Xcode's "Fix Issues" flow is still one click
    // from writing Manual here — which would break the dev box while CI, which
    // overwrites the setting anyway, stayed green and said nothing.
    for (final c in appTargets()) {
      expect(
        c.settings['CODE_SIGN_STYLE'],
        'Automatic',
        reason:
            'app-target config ${c.name} (${c.id}) must pin CODE_SIGN_STYLE = '
            'Automatic; found ${c.settings['CODE_SIGN_STYLE'] ?? '(absent)'} — '
            'the COMMITTED project is what the dev box and the cable rig build '
            'with, and they need automatic signing. CI overwrites this to '
            'Manual at build time by design (ADR-032 D7), so a regression here '
            'is invisible to the release lane and breaks only the human',
      );
    }
  });

  test('no app-target config carries a WRONG team or Manual signing', () {
    // The scoping is deliberate (ADR-029 D3 rev 2, finding F4): a team id or a
    // Manual style on RunnerTests is harmless — that target signs nothing and
    // `flutter build ipa` never builds it. Asserting file-wide would redden on
    // a harmless edit, and a sentinel that cries wolf gets relaxed.
    for (final c in appTargets()) {
      final team = c.settings['DEVELOPMENT_TEAM'];
      expect(
        team,
        anyOf(isNull, teamId),
        reason:
            'app-target config ${c.name} (${c.id}) carries team $team — a '
            'wrong team is the drift that actually happens (a second Apple '
            'account, a copied project); it signs, then fails at upload',
      );
      expect(
        c.settings['CODE_SIGN_STYLE'],
        isNot('Manual'),
        reason: 'app-target config ${c.name} (${c.id}) flipped to Manual',
      );
    }
  });

  test('the squatted com.hayati.app bundle id appears NOWHERE', () {
    // ADR-027 renamed off `com.hayati.app` because another Apple team owns it.
    // On the Dart side that rename is pinned by firebase_bootstrap_test.dart;
    // on the Xcode side, before this sentinel, it was asserted by nothing at
    // all — and a revert would build fine and fail only at Apple.
    expect(
      File(pbxprojPath).readAsStringSync(),
      isNot(contains('com.hayati.app')),
      reason:
          'com.hayati.app is SQUATTED on Apple (ADR-027) — it cannot be '
          'registered to team $teamId, so a build carrying it cannot ship',
    );
  });
}

/// One `XCBuildConfiguration` block: its id, its `name` (Debug/Release/Profile)
/// and its `buildSettings` as a flat map.
class _BuildConfig {
  _BuildConfig(this.id, this.name, this.settings);

  final String id;
  final String name;
  final Map<String, String> settings;

  String? get bundleId => settings['PRODUCT_BUNDLE_IDENTIFIER'];
}

/// Splits a pbxproj into its `XCBuildConfiguration` blocks.
///
/// Deliberately a small hand parser rather than a plist library: the pbxproj is
/// OpenStep-format (not XML), no dependency in this repo reads it, and the
/// assertions need only `name` + scalar `buildSettings`. Nested values (the
/// `LD_RUNPATH_SEARCH_PATHS` array) are skipped rather than modelled — none of
/// the signing settings is a list.
List<_BuildConfig> _parseBuildConfigs(String src) {
  final blockPattern = RegExp(
    r'\n\t\t([0-9A-F]{24}) /\* (\w+) \*/ = \{\n'
    r'\t\t\tisa = XCBuildConfiguration;'
    r'(.*?)'
    r'\n\t\t\};',
    dotAll: true,
  );
  final settingPattern = RegExp(r'^\t\t\t\t([A-Z_0-9]+) = "?([^";\n]*)"?;$');

  return blockPattern.allMatches(src).map((m) {
    final settings = <String, String>{};
    for (final line in m.group(3)!.split('\n')) {
      final s = settingPattern.firstMatch(line);
      if (s != null) settings[s.group(1)!] = s.group(2)!;
    }
    return _BuildConfig(m.group(1)!, m.group(2)!, settings);
  }).toList();
}
