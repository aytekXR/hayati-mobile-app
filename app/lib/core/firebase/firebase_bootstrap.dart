import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/app_config.dart';
import 'firebase_options_dev.dart';
import 'firebase_options_prod.dart';

/// Opt-in Firebase Auth emulator wiring (repo-root `firebase.json`):
///
/// ```sh
/// npx firebase-tools emulators:start --only auth --project demo-hayati
/// flutter run -t lib/main_dev.dart --dart-define=USE_AUTH_EMULATOR=true
/// ```
const bool kUseAuthEmulator = bool.fromEnvironment('USE_AUTH_EMULATOR');

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
}
