// Auth-flow round-trip against the Firebase Auth EMULATOR — device/simulator
// only (firebase_auth needs platform channels; this cannot run in the plain
// `flutter test` VM, which is why it lives here and not in test/).
//
// Run (two terminals, repo root then app/):
//   npx firebase-tools emulators:start --only auth --project demo-hayati
//   flutter test integration_test --dart-define=USE_AUTH_EMULATOR=true \
//     -d <device>   # iOS simulator; physical device needs
//                   # --dart-define=AUTH_EMULATOR_HOST=<host LAN IP>
//
// CI wiring (macOS runner + simulator + emulator) is deferred to M1.2 —
// ci-debt issue #6.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/features/auth/data/firebase_auth_repository.dart';
import 'package:hayati_app/features/auth/data/google_auth_gateway.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:integration_test/integration_test.dart';

/// Substitutes the interactive Google flow: the Auth emulator accepts an
/// unsigned `id_token` whose payload is plain JSON (validated in Session 003
/// via the emulator REST API), so no real Google account is involved.
class _EmulatorGoogleAuthGateway implements GoogleAuthGateway {
  @override
  Future<AuthCredential?> acquireCredential() async =>
      GoogleAuthProvider.credential(
        idToken: jsonEncode({
          'sub': 'emulator-uid-1',
          'email': 'emulator@example.com',
        }),
      );

  @override
  Future<void> signOut() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!kUseAuthEmulator) {
      fail(
        'This suite only runs against the Auth emulator. '
        'Pass --dart-define=USE_AUTH_EMULATOR=true (see file header).',
      );
    }
    await initializeFirebase(const AppConfig(flavor: AppFlavor.dev));
  });

  testWidgets('google sign-in round-trip through the repository', (
    tester,
  ) async {
    final repository = FirebaseAuthRepository(
      firebaseAuth: FirebaseAuth.instance,
      googleGateway: _EmulatorGoogleAuthGateway(),
    );

    final user = await repository.signInWithGoogle();
    expect(user.email, 'emulator@example.com');
    expect(user.uid, isNotEmpty);
    expect(repository.currentUser, user);

    // A fresh subscription re-emits the current state first.
    await expectLater(
      repository.authStateChanges(),
      emitsThrough(
        predicate<AuthUser?>((u) => u?.email == 'emulator@example.com'),
      ),
    );

    await repository.signOut();
    expect(repository.currentUser, isNull);
    await expectLater(repository.authStateChanges(), emitsThrough(isNull));
  });
}
