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

  test('every channel METHOD the Dart side calls is handled in Swift', () {
    // A typo here is not a crash — it is a `MissingPluginException` the adapters
    // swallow into `false`/`null`, i.e. a feature that quietly reports itself
    // unsupported and vanishes from the UI.
    const methods = [
      'supportsAlternateIcons',
      'getAlternateIconName',
      'setAlternateIconName',
      'biometricEnrollmentState',
    ];
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
