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
// CI runs this suite on the main-only `integration-emulator` job (macOS runner +
// iOS simulator + auth/firestore emulators via `firebase emulators:exec`); see
// .github/workflows/ci.yml (ci-debt #6). It is a POST-MERGE signal, so run it
// locally (above) before merging, or trigger it on a branch with
// `gh workflow run ci.yml --ref <branch>`.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/features/auth/data/apple_auth_gateway.dart';
import 'package:hayati_app/features/auth/data/firebase_auth_repository.dart';
import 'package:hayati_app/features/auth/data/google_auth_gateway.dart';
import 'package:hayati_app/features/auth/data/phone_auth_gateway.dart';
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

/// Substitutes the native Sign in with Apple flow: the Auth emulator accepts an
/// unsigned `apple.com` id_token whose payload is plain JSON — the same trick as
/// Google, proven over REST against demo-hayati. NO rawNonce: an unsigned JSON
/// token has no nonce claim for Firebase to match, so the emulator credential
/// omits it (unlike the production `credentialWithIDToken` path). signInMethod
/// defaults to 'oauth' here; the emulator keys on providerId, so that is harmless
/// (brief-6-apple.md — pin 'apple.com' only if a round-trip ever rejects it).
class _EmulatorAppleAuthGateway implements AppleAuthGateway {
  @override
  Future<AuthCredential?> acquireCredential() async =>
      OAuthProvider('apple.com').credential(
        idToken: jsonEncode({
          'sub': 'emulator-apple-uid-1',
          'email': 'apple-emulator@example.com',
        }),
      );
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
      appleGateway: _EmulatorAppleAuthGateway(),
      phoneGateway: FirebaseVerifyPhoneGateway(FirebaseAuth.instance),
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

  testWidgets('apple sign-in round-trip through the repository', (
    tester,
  ) async {
    final repository = FirebaseAuthRepository(
      firebaseAuth: FirebaseAuth.instance,
      googleGateway: _EmulatorGoogleAuthGateway(),
      appleGateway: _EmulatorAppleAuthGateway(),
      phoneGateway: FirebaseVerifyPhoneGateway(FirebaseAuth.instance),
    );

    final user = await repository.signInWithApple();
    expect(user.email, 'apple-emulator@example.com');
    expect(user.uid, isNotEmpty);
    expect(repository.currentUser, user);

    // A fresh subscription re-emits the current state first.
    await expectLater(
      repository.authStateChanges(),
      emitsThrough(
        predicate<AuthUser?>((u) => u?.email == 'apple-emulator@example.com'),
      ),
    );

    await repository.signOut();
    expect(repository.currentUser, isNull);
    await expectLater(repository.authStateChanges(), emitsThrough(isNull));
  });
}
