import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/app_config.dart';
import 'firebase_options_dev.dart';
import 'firebase_options_prod.dart';

/// Opt-in Firebase Auth emulator wiring (repo-root `firebase.json`):
///
/// ```sh
/// npx firebase-tools emulators:start --only auth,firestore --project demo-hayati
/// flutter run -t lib/main_dev.dart --dart-define=USE_AUTH_EMULATOR=true \
///   --dart-define=USE_FIRESTORE_EMULATOR=true
/// ```
///
/// The Firestore emulator needs a JVM (Java 21+, firebase-tools 15.x) —
/// auth-only runs do not.
const bool kUseAuthEmulator = bool.fromEnvironment('USE_AUTH_EMULATOR');

/// Opt-in Firestore emulator wiring, symmetric with [kUseAuthEmulator].
const bool kUseFirestoreEmulator = bool.fromEnvironment(
  'USE_FIRESTORE_EMULATOR',
);

/// Host override for physical devices, where the emulator is not on
/// localhost: `--dart-define=AUTH_EMULATOR_HOST=192.168.1.20`.
const String kAuthEmulatorHost = String.fromEnvironment(
  'AUTH_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

const int kAuthEmulatorPort = int.fromEnvironment(
  'AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);

const int kFirestoreEmulatorPort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

/// Pure flavor→options selection, unit-tested without any Firebase mock.
FirebaseOptions firebaseOptionsFor(AppFlavor flavor) => switch (flavor) {
  AppFlavor.dev => DevFirebaseOptions.currentPlatform,
  AppFlavor.prod => ProdFirebaseOptions.currentPlatform,
};

/// Initializes Firebase for [config]'s flavor. Called by the flavor
/// entrypoints after `WidgetsFlutterBinding.ensureInitialized()`.
Future<void> initializeFirebase(AppConfig config) async {
  try {
    await Firebase.initializeApp(options: firebaseOptionsFor(config.flavor));
  } on FirebaseException catch (failure) {
    // The native default app survives a hot restart (and the test-VM mock
    // pre-registers one) — reuse it. A flavor never changes within a
    // process, so the surviving app's options are the right ones.
    if (failure.code != 'duplicate-app') {
      rethrow;
    }
  }
  if (kUseAuthEmulator) {
    // Must run before any other FirebaseAuth call in the process.
    await FirebaseAuth.instance.useAuthEmulator(
      kAuthEmulatorHost,
      kAuthEmulatorPort,
    );
  }
  if (kUseFirestoreEmulator) {
    // Must run before ANY Firestore call: the native config snapshots
    // Settings on first use and a later emulator switch is silently ignored
    // (verified in the cloud_firestore 6.6.0 source, Session 004). Shares
    // the auth host override — one LAN IP serves both emulators on device.
    FirebaseFirestore.instance.useFirestoreEmulator(
      kAuthEmulatorHost,
      kFirestoreEmulatorPort,
    );
  }
}
