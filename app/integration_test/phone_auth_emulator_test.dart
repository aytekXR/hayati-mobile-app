// Phone-auth round-trip against the Firebase Auth EMULATOR — device/simulator
// only (firebase_auth's `verifyPhoneNumber` needs platform channels, so this
// cannot run in the plain `flutter test` VM; that is why it lives here and not
// in test/).
//
// Against the emulator no APNs/reCAPTCHA config is needed: `sendVerificationCode`
// mints a RANDOM 6-digit code per request (never hardcode it) and exposes it at
// GET /emulator/v1/projects/<project>/verificationCodes. `<project>` is the
// emulator's `--project` (single-project mode), NOT `FirebaseOptions.projectId`:
// the Auth emulator resolves every request to that one project regardless of the
// SDK's configured project (brief-3.md; verified against firebase-tools).
//
// Run (two terminals, repo root then app/):
//   npx firebase-tools emulators:start --only auth --project demo-hayati
//   flutter test integration_test/phone_auth_emulator_test.dart \
//     --dart-define=USE_AUTH_EMULATOR=true \
//     -d <device>   # iOS simulator; a physical device needs
//                   # --dart-define=AUTH_EMULATOR_HOST=<host LAN IP>
//
// CI runs this suite on the main-only `integration-emulator` job (macOS runner +
// iOS simulator + auth/firestore emulators via `firebase emulators:exec`); see
// .github/workflows/ci.yml (ci-debt #6). It is a POST-MERGE signal, so run it
// locally (above) before merging, or trigger it on a branch with
// `gh workflow run ci.yml --ref <branch>`.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/features/auth/data/apple_auth_gateway.dart';
import 'package:hayati_app/features/auth/data/firebase_auth_repository.dart';
import 'package:hayati_app/features/auth/data/google_auth_gateway.dart';
import 'package:hayati_app/features/auth/data/phone_auth_gateway.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:integration_test/integration_test.dart';

/// The emulator's `--project` (single-project mode). The Auth emulator stores
/// state under this project for EVERY request, independent of the SDK's
/// `FirebaseOptions.projectId` — see the file header.
const String _emulatorProjectId = 'demo-hayati';

/// This suite exercises only the phone flow, but [FirebaseAuthRepository]
/// requires all gateways. [acquireCredential] throws so an accidental Google
/// sign-in fails loudly; [signOut] stays a no-op because `repository.signOut`
/// always calls it (it clears the Google chooser before Firebase).
class _UnusedGoogleGateway implements GoogleAuthGateway {
  @override
  Future<AuthCredential?> acquireCredential() => throw UnsupportedError(
    'Google gateway is not exercised by the phone suite',
  );

  @override
  Future<void> signOut() async {}
}

/// Apple counterpart to [_UnusedGoogleGateway]; never invoked here (the
/// interface exposes no signOut — Apple keeps no client-side session).
class _UnusedAppleGateway implements AppleAuthGateway {
  @override
  Future<AuthCredential?> acquireCredential() => throw UnsupportedError(
    'Apple gateway is not exercised by the phone suite',
  );
}

/// Reads the fake SMS code the emulator minted for [phoneNumber] from its admin
/// REST endpoint. Codes are random per request, so tests MUST read them back
/// rather than assume a value (brief-3.md). Uses `dart:io`'s [HttpClient] to
/// avoid a `package:http` dependency. Returns the most recent code for the
/// number (the endpoint accumulates every code minted this emulator session).
Future<String> _readEmulatorSmsCode(String phoneNumber) async {
  final uri = Uri.parse(
    'http://$kAuthEmulatorHost:$kAuthEmulatorPort'
    '/emulator/v1/projects/$_emulatorProjectId/verificationCodes',
  );
  final client = HttpClient();
  try {
    // `codeSent` (which resolves `sendPhoneCode`) fires after the emulator has
    // already stored the code, so one read suffices; the short bounded poll only
    // guards against incidental lag and never masks a genuine miss (it throws
    // with the raw body once exhausted).
    for (var attempt = 0; ; attempt++) {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final codes =
          (jsonDecode(body) as Map<String, dynamic>)['verificationCodes']
              as List<dynamic>;
      final matches = codes
          .cast<Map<String, dynamic>>()
          .where((entry) => entry['phoneNumber'] == phoneNumber)
          .toList();
      if (matches.isNotEmpty) {
        return matches.last['code'] as String;
      }
      if (attempt >= 4) {
        throw StateError(
          'Emulator returned no verification code for $phoneNumber. '
          'Response body: $body',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  } finally {
    client.close();
  }
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

  FirebaseAuthRepository buildRepository() => FirebaseAuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    googleGateway: _UnusedGoogleGateway(),
    appleGateway: _UnusedAppleGateway(),
    // The REAL verifyPhoneNumber path — the whole point of this suite.
    phoneGateway: FirebaseVerifyPhoneGateway(FirebaseAuth.instance),
  );

  testWidgets(
    'phone verify → code → sign-in round-trip through the repository',
    (tester) async {
      const phoneNumber = '+16505551234';
      final repository = buildRepository();

      final session = await repository.sendPhoneCode(phoneNumber);
      expect(session.verificationId, isNotEmpty);

      final code = await _readEmulatorSmsCode(phoneNumber);
      final user = await repository.confirmPhoneCode(session, code);

      // Phone sign-in has no email; the uid is the stable identity assertion.
      expect(user.uid, isNotEmpty);
      expect(repository.currentUser, user);

      // A fresh subscription re-emits the current state first.
      await expectLater(
        repository.authStateChanges(),
        emitsThrough(predicate<AuthUser?>((u) => u?.uid == user.uid)),
      );

      await repository.signOut();
      expect(repository.currentUser, isNull);
      await expectLater(repository.authStateChanges(), emitsThrough(isNull));
    },
  );

  testWidgets('wrong SMS code surfaces AuthInvalidCodeException', (
    tester,
  ) async {
    const phoneNumber = '+16505554321';
    final repository = buildRepository();

    final session = await repository.sendPhoneCode(phoneNumber);
    final realCode = await _readEmulatorSmsCode(phoneNumber);
    // Deterministically pick a code that differs from the emulator's random one
    // (never hardcode a "wrong" value that could collide with a real 6 digits).
    final wrongCode = realCode == '000000' ? '111111' : '000000';

    await expectLater(
      repository.confirmPhoneCode(session, wrongCode),
      throwsA(isA<AuthInvalidCodeException>()),
    );
    expect(repository.currentUser, isNull);
  });
}
