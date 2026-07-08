import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Dev-flavor Firebase options — PLACEHOLDER values, not a real project.
///
/// Session 003 ran emulator-only (founder `firebase login` unavailable —
/// docs/resume-prompt.md fallback). The `demo-` projectId keeps the Firebase
/// emulators credential-free; every other field is a syntactically valid
/// dummy. Replaced wholesale by `flutterfire configure` against the real
/// `hayati-dev` project in M1.2 (issue #5).
///
/// Real Firebase config files are NOT secrets (API keys are identifiers,
/// restricted per-platform in the Google Cloud console) — the generated
/// options will be committed here just like these placeholders.
class DevFirebaseOptions {
  DevFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DevFirebaseOptions: web is out of MVP scope.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DevFirebaseOptions: unsupported platform $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDEV0PLACEHOLDER0ANDROID000000000000',
    appId: '1:000000000000:android:00000000000000000000d0',
    messagingSenderId: '000000000000',
    projectId: 'demo-hayati',
    storageBucket: 'demo-hayati.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDEV0PLACEHOLDER0IOS0000000000000000',
    appId: '1:000000000000:ios:00000000000000000000d1',
    messagingSenderId: '000000000000',
    projectId: 'demo-hayati',
    storageBucket: 'demo-hayati.appspot.com',
    iosBundleId: 'com.hayati.app',
  );
}
