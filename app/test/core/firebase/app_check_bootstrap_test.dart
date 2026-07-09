import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/app_check_bootstrap.dart';

void main() {
  // Pure flavor→provider selection only. activateAppCheck is deliberately not
  // exercised here: it drives a Pigeon channel and throws in the plain VM, so
  // it lives in the entrypoints, never on a test path (docs/resume-prompt.md
  // M1.3). These plain const provider objects are VM-safe to construct.
  group('appCheckAppleProviderFor', () {
    test('dev selects the Apple debug provider', () {
      final provider = appCheckAppleProviderFor(AppFlavor.dev);
      expect(provider, isA<AppleDebugProvider>());
      expect(provider.type, 'debug');
    });

    test('prod selects the App Attest provider', () {
      final provider = appCheckAppleProviderFor(AppFlavor.prod);
      expect(provider, isA<AppleAppAttestProvider>());
      expect(provider.type, 'appAttest');
    });
  });

  group('appCheckAndroidProviderFor', () {
    test('dev selects the Android debug provider', () {
      final provider = appCheckAndroidProviderFor(AppFlavor.dev);
      expect(provider, isA<AndroidDebugProvider>());
      expect(provider.type, 'debug');
    });

    test('prod selects the Play Integrity provider', () {
      final provider = appCheckAndroidProviderFor(AppFlavor.prod);
      expect(provider, isA<AndroidPlayIntegrityProvider>());
      expect(provider.type, 'playIntegrity');
    });
  });
}
