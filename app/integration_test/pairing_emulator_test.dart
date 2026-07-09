// Invite issuing against the Auth + Functions EMULATORS —
// device/simulator only (cloud_functions needs platform channels; this cannot
// run in the plain `flutter test` VM, which is why it lives here).
//
// The functions emulator require()s functions/lib/index.js (it never compiles
// TS), so `npm run build` in functions/ must land first; the firestore emulator
// (which the createInvite function writes through) needs Java 21+ on PATH
// (firebase-tools 15.x). Run (two terminals, repo root then app/):
//   npx firebase-tools emulators:start \
//     --only auth,firestore,functions --project demo-hayati
//   flutter test integration_test/pairing_emulator_test.dart \
//     --dart-define=USE_AUTH_EMULATOR=true \
//     --dart-define=USE_FIRESTORE_EMULATOR=true \
//     --dart-define=USE_FUNCTIONS_EMULATOR=true \
//     -d <device>   # physical device needs
//                   # --dart-define=AUTH_EMULATOR_HOST=<host LAN IP>
//
// CI runs this suite on the main-only `integration-emulator` job (macOS runner +
// iOS simulator + auth/firestore/functions emulators via `firebase
// emulators:exec`); see .github/workflows/ci.yml. It is a POST-MERGE signal, so
// run it locally (above) before merging, or trigger it on a branch with
// `gh workflow run ci.yml --ref <branch>`.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/features/pairing/data/functions_invite_repository.dart';
import 'package:integration_test/integration_test.dart';

// The server's code alphabet (functions/src/invites/invite-code.ts): uppercase
// A–Z + digits minus the ambiguous 0/O/1/I/L, exactly 8 chars.
final _codePattern = RegExp(r'^[A-HJ-KM-NP-Z2-9]{8}$');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!kUseAuthEmulator || !kUseFunctionsEmulator) {
      fail(
        'This suite only runs against the emulators. Pass '
        '--dart-define=USE_AUTH_EMULATOR=true '
        '--dart-define=USE_FUNCTIONS_EMULATOR=true (see file header).',
      );
    }
    await initializeFirebase(const AppConfig(flavor: AppFlavor.dev));
    // The Auth emulator accepts an unsigned JSON id_token (Session 003).
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: jsonEncode({
          'sub': 'invite-emulator-uid',
          'email': 'invite@example.com',
        }),
      ),
    );
  });

  testWidgets('createInvite issues a code and re-issues it idempotently', (
    tester,
  ) async {
    final repository = FunctionsInviteRepository();

    final first = await repository.createInvite();
    expect(first.code, matches(_codePattern));
    expect(first.reused, isFalse);
    // The server sets a 48h TTL at call time; allow slack for round-trip.
    final expected = DateTime.now().add(const Duration(hours: 48));
    expect(first.expiresAt.difference(expected).inMinutes.abs(), lessThan(5));

    // One-active-invite policy: a second call within the TTL returns the SAME
    // code, flagged reused (idempotent re-issue).
    final second = await repository.createInvite();
    expect(second.code, first.code);
    expect(second.reused, isTrue);
  });
}
