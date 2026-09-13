import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/settings/domain/app_icon_switcher.dart';

/// SOURCE-SENTINEL parity between the Dart channel client and its Swift handler
/// (the `biometric_only_contract_test.dart` mold).
///
/// WHY this shape: the `hayati/device_privacy` channel is the app's ONE platform
/// channel, and NOTHING else can catch a drift across it. `flutter test` never
/// touches a platform channel (the adapters are seams, by design). CI's
/// `flutter build ios --no-codesign` compiles the Swift and runs actool, but it
/// never RUNS the app — so a renamed method, a renamed channel, or an icon-set
/// name that no longer matches the asset catalog all compile perfectly and ship
/// a **silently dead feature behind a green pipeline**. That failure mode —
/// green everything, feature simply absent — is the one the M6.1
/// post-implementation review called out (findings IOS-1 / VB-1), and a string
/// comparison is the only thing standing in front of it.
///
/// The runtime halves still belong to operator item 4's on-device checklist.
/// This test only guarantees the two sides are TALKING ABOUT THE SAME THING.
void main() {
  const dartPath = 'lib/core/platform/device_privacy_channel.dart';
  const swiftPath = 'ios/Runner/AppDelegate.swift';
  const catalogPath = 'ios/Runner/Assets.xcassets';
  const pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';

  late String dart;
  late String swift;

  String read(String path) {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the sentinel must fail loudly if $path is moved or renamed, rather '
          'than pass vacuously — re-point it and KEEP the pin',
    );
    return file.readAsStringSync();
  }

  setUpAll(() {
    dart = read(dartPath);
    swift = read(swiftPath);
  });

  test('the channel NAME is identical on both sides', () {
    const channel = 'hayati/device_privacy';
    expect(dart, contains("'$channel'"));
    expect(swift, contains('"$channel"'));
  });

  // The pin. Hoisted out of the first test at S102 so the REVERSE direction can
  // read it too — a list that only one assertion can see cannot be checked for
  // completeness, and it was incomplete for two sessions.
  const methods = [
    'supportsAlternateIcons',
    'getAlternateIconName',
    'setAlternateIconName',
    'biometricEnrollmentState',
    // ADR-046 D4. The one door out of a declined notification permission —
    // and the method whose absence would be least visible, because the
    // adapter's throw is caught by a settings row that would then just say
    // "couldn't open Settings" on a perfectly healthy phone.
    'openNotificationSettings',
    // ⚠️ THE LIST STOPPED HERE FOR TWO SESSIONS (added S102). ADR-074 and
    // ADR-076 each put a method on this channel and neither was pinned, so
    // the sentinel written to stop *"a renamed method ships a silently dead
    // feature behind a green pipeline"* did not cover the two newest methods
    // — including the one the entire push feature now rests on. A rename of
    // `ensureRemoteNotificationRegistration` on either side would have
    // reproduced ADR-076's own bug (nobody asks APNs, no address, no error)
    // with every gate green. That is the exact failure this file exists for.
    'apnsRegistrationFailure',
    'ensureRemoteNotificationRegistration',
  ];

  test('every channel METHOD the Dart side calls is handled in Swift', () {
    // A typo here is not a crash — it is a `MissingPluginException` the adapters
    // swallow into `false`/`null`, i.e. a feature that quietly reports itself
    // unsupported and vanishes from the UI.
    for (final method in methods) {
      expect(
        dart,
        contains("'$method'"),
        reason: '$method is not invoked by the Dart client',
      );
      expect(
        swift,
        contains('case "$method"'),
        reason: '$method has no Swift handler — the call would silently no-op',
      );
    }
  });

  test('and the pin is COMPLETE in both directions (S102)', () {
    // ⚠️ WHY THIS EXISTS. The test above walks the list and proves each entry
    // is on both sides — which says nothing about a method that is on both
    // sides and NOT in the list. That is not hypothetical: `apnsRegistrationFailure`
    // (ADR-074) and `ensureRemoteNotificationRegistration` (ADR-076) were both
    // shipped, both wired end to end, and neither was pinned, so for two
    // sessions the sentinel was green over an unpinned surface.
    //
    // Both directions, from the files themselves rather than from a count kept
    // by hand:
    //   * every `case "x"` in the Swift handler is in the list;
    //   * every `Future<…> …invokeMethod…('x')` in the Dart client is in the list.
    final swiftCases = RegExp(
      r'case "([A-Za-z0-9_]+)":',
    ).allMatches(swift).map((m) => m.group(1)!).toSet();
    expect(
      swiftCases.difference(methods.toSet()),
      isEmpty,
      reason:
          'AppDelegate handles a channel method this sentinel does not pin — '
          'add it to `methods` above (and to the dartdoc list), or the next '
          'rename of it ships a dead feature behind a green pipeline',
    );

    final dartInvocations = RegExp(
      r"invokeMethod<[^>]*>\('([A-Za-z0-9_]+)'",
    ).allMatches(dart).map((m) => m.group(1)!).toSet();
    expect(
      dartInvocations.difference(methods.toSet()),
      isEmpty,
      reason:
          'DevicePrivacyChannel invokes a method this sentinel does not pin — '
          'add it to `methods` above',
    );
    expect(
      dartInvocations,
      hasLength(methods.length),
      reason:
          'the Dart client no longer invokes every pinned method — a pin over '
          'a call site that is gone passes vacuously',
    );
  });

  test('the dartdoc SAYS how many methods there are, and is right (S102)', () {
    // The class dartdoc opens *"It carries the seven native methods this layer
    // needs"* and then lists them. That sentence was already saying "seven"
    // while only six bullets existed — the count and the list drifted apart
    // inside one comment, which is how a reader learns to stop trusting either.
    const words = {
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
    };
    final stated = RegExp(
      r'carries the (\w+) native methods',
    ).firstMatch(dart)?.group(1);
    expect(
      stated,
      isNotNull,
      reason:
          'the dartdoc no longer states a method count — restore the sentence '
          'or delete this test deliberately, do not let it pass vacuously',
    );
    expect(
      words[stated],
      methods.length,
      reason:
          'the dartdoc says "$stated" but the channel pins ${methods.length} '
          'methods',
    );

    final bullets = RegExp(
      r'^/// \* `',
      multiLine: true,
    ).allMatches(dart).length;
    expect(
      bullets,
      methods.length,
      reason:
          'the dartdoc lists $bullets methods but the channel pins '
          '${methods.length} — a missing bullet is how the seventh method went '
          'undocumented for a session',
    );
  });

  test(
    'the alternate-icon NAME matches the asset catalog and the build config',
    () {
      // `setAlternateIconName` takes the ASSET-CATALOG SET NAME. If the Dart
      // constant, the .appiconset directory, and the pbxproj's
      // ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES ever disagree, iOS simply
      // refuses the swap at runtime — with a perfectly green build.
      expect(
        Directory('$catalogPath/$kDiscreetIconName.appiconset').existsSync(),
        isTrue,
        reason:
            'kDiscreetIconName ($kDiscreetIconName) has no matching .appiconset',
      );

      final pbxproj = read(pbxprojPath);
      final declarations = RegExp(
        'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = $kDiscreetIconName;',
      ).allMatches(pbxproj).length;
      expect(
        declarations,
        3,
        reason:
            'the alternate icon must be declared in all THREE build configs '
            '(Debug/Release/Profile) — a missing one ships a build where the '
            'discreet icon does not exist',
      );
    },
  );

  test('the discreet icon asset is present and OPAQUE', () {
    // actool rejects alpha in app icons; a stray RGBA icon fails the iOS build
    // (or, worse under some toolchains, is silently dropped).
    final contents = read(
      '$catalogPath/$kDiscreetIconName.appiconset/Contents.json',
    );
    expect(contents, contains('"idiom" : "universal"'));
    expect(contents, contains('"platform" : "ios"'));
    expect(contents, contains('"size" : "1024x1024"'));
    expect(
      contents,
      isNot(contains('"scale"')),
      reason:
          'the Xcode 14+ single-size icon slot omits `scale`; mixing it with '
          'the legacy per-slot shape risks actool emitting no '
          'CFBundleAlternateIcons at all — a dead feature, green pipeline',
    );

    final png = File(
      '$catalogPath/$kDiscreetIconName.appiconset/Icon-Discreet-1024.png',
    );
    expect(png.existsSync(), isTrue, reason: 'the icon named in Contents.json');

    // PNG colour type lives at byte 25 of the IHDR chunk: 2 = truecolour (RGB,
    // no alpha), 6 = RGBA. App icons must not carry alpha.
    final bytes = png.readAsBytesSync();
    expect(bytes[25], 2, reason: 'the app icon must be opaque RGB, not RGBA');
  });
}
