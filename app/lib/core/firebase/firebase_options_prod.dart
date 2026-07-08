import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Prod-flavor Firebase options — PLACEHOLDER values, not a real project.
///
/// See `firebase_options_dev.dart` for the emulator-only fallback context;
/// the same M1.2 `flutterfire configure` pass (issue #5) replaces this file
/// against the real production project. Until then the prod flavor boots
/// Firebase with inert options — no real backend is reachable, by design.
class ProdFirebaseOptions {
  ProdFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('ProdFirebaseOptions: web is out of MVP scope.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'ProdFirebaseOptions: unsupported platform $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyPRD0PLACEHOLDER0ANDROID000000000000',
    appId: '1:000000000001:android:00000000000000000000f0',
    messagingSenderId: '000000000001',
    projectId: 'hayati-prod',
    storageBucket: 'hayati-prod.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPRD0PLACEHOLDER0IOS0000000000000000',
    appId: '1:000000000001:ios:00000000000000000000f1',
    messagingSenderId: '000000000001',
    projectId: 'hayati-prod',
    storageBucket: 'hayati-prod.appspot.com',
    iosBundleId: 'com.hayati.app',
  );
}
