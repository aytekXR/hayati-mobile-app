// Invite issuing + the full two-user pairing acceptance against the Auth +
// Firestore + Functions EMULATORS — device/simulator only (cloud_functions /
// cloud_firestore need platform channels; this cannot run in the plain
// `flutter test` VM, which is why it lives here).
//
// "Two emulated devices" is approximated as two users signed in SEQUENTIALLY in
// ONE process: sign A out, sign B in on the same FirebaseAuth instance. There is
// no second device to reach, and the pairing outcome (couple doc + both users'
// coupleId) is a server-side fact readable by whichever member is signed in — so
// one process is sufficient to prove the acceptance criterion.
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/features/pairing/data/functions_invite_repository.dart';
import 'package:hayati_app/features/pairing/data/http_invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview.dart';
import 'package:hayati_app/features/profile/data/firestore_profile_repository.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

// The server's code alphabet (functions/src/invites/invite-code.ts): uppercase
// A–Z + digits minus the ambiguous 0/O/1/I/L, exactly 8 chars.
final _codePattern = RegExp(r'^[A-HJ-KM-NP-Z2-9]{8}$');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!kUseAuthEmulator || !kUseFirestoreEmulator || !kUseFunctionsEmulator) {
      fail(
        'This suite only runs against the emulators. Pass '
        '--dart-define=USE_AUTH_EMULATOR=true '
        '--dart-define=USE_FIRESTORE_EMULATOR=true '
        '--dart-define=USE_FUNCTIONS_EMULATOR=true (see file header).',
      );
    }
    // The default app must carry the EMULATOR project id, not a flavor's:
    // cloud_functions derives the emulated callable URL from
    // FirebaseOptions.projectId, and the functions emulator serves functions
    // ONLY under its `--project` (demo-hayati) — dev options 404 (NOT FOUND).
    // The auth/firestore emulators resolve any project id, which is why the
    // older suites never hit this. Every value besides projectId is a dummy,
    // but the SHAPES must stay valid: the native Firebase iOS SDK validates
    // GOOGLE_APP_ID structure (`1:<number>:ios:<hex>`) at configure time, so
    // a free-form appId kills setUpAll before any Dart error can print.
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyD-demo-hayati-emulator-0000000000',
          appId: '1:870954957461:ios:0000000000000000000000',
          messagingSenderId: '870954957461',
          projectId: 'demo-hayati',
          iosBundleId: 'com.hayati.app',
        ),
      );
      await FirebaseAuth.instance.useAuthEmulator(
        kAuthEmulatorHost,
        kAuthEmulatorPort,
      );
      // The join flow writes users/{uid}.coupleId and the couples/ doc through
      // Firestore, so the acceptance test needs the Firestore emulator wired too
      // (the createInvite-only test above never touched it).
      FirebaseFirestore.instance.useFirestoreEmulator(
        kAuthEmulatorHost,
        kFirestoreEmulatorPort,
      );
      FirebaseFunctions.instanceFor(
        region: kFunctionsRegion,
      ).useFunctionsEmulator(kAuthEmulatorHost, kFunctionsEmulatorPort);
    } catch (error, stack) {
      // The CI runner is headless — surface the real failure instead of the
      // framework's bare "(setUpAll) did not complete".
      fail('emulator bootstrap failed: $error\n$stack');
    }
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

  testWidgets('two-user pairing: preview → join creates the couple, and a '
      'second join on the same code is rejected consumed', (tester) async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final profiles = FirestoreProfileRepository(firestore: firestore);
    final invites = FunctionsInviteRepository();

    // Signs out the current session and signs in the fake federated user
    // described by [claims] (the Auth emulator accepts an unsigned JSON id_token,
    // Session 003), returning the resulting Firebase uid — NOT assumed equal to
    // the token 'sub' (the emulator mints its own uid per federated identity).
    Future<String> switchTo(Map<String, Object?> claims) async {
      await auth.signOut();
      await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: jsonEncode(claims)),
      );
      return auth.currentUser!.uid;
    }

    const profile = RelationshipProfile(
      status: RelationshipStatus.married,
      contentLanguage: ContentLanguage.tr,
      register: ContentRegister.respectful,
    );

    // --- User A (creator): a Google identity carrying a display 'name' (the
    // preview reads creatorDisplayName off the AUTH record, not the users doc),
    // an onboarding profile, and one issued invite.
    final creatorUid = await switchTo({
      'sub': 'pair-creator-uid',
      'email': 'creator@example.com',
      'name': 'Aylin',
    });
    await profiles.saveProfile(creatorUid, profile);
    final code = (await invites.createInvite()).code;
    expect(code, matches(_codePattern));

    // --- User B (joiner): a distinct signed-in user (the "second device"), with
    // their own profile.
    final joinerUid = await switchTo({
      'sub': 'pair-joiner-uid',
      'email': 'joiner@example.com',
    });
    expect(joinerUid, isNot(creatorUid));
    await profiles.saveProfile(joinerUid, profile);

    // --- Preview over the REAL zero-auth HTTP repository against the emulator
    // (http://127.0.0.1:5001/demo-hayati/europe-west1/invitePreview): a live
    // invite is 'valid' and surfaces the creator's display name.
    final client = http.Client();
    addTearDown(client.close);
    final previewRepository = HttpInvitePreviewRepository(
      client: client,
      baseUri: invitePreviewUri(flavor: AppFlavor.dev),
    );
    final preview = await previewRepository.preview(code);
    expect(preview.status, InvitePreviewStatus.valid);
    expect(preview.creatorDisplayName, 'Aylin');

    // --- Join through the callable repository (app sends only {code}; the
    // server defaults the couple timezone to Europe/Istanbul).
    final coupleId = await invites.joinInvite(code);
    expect(coupleId, isNotEmpty);

    // B's users doc now carries the server-stamped coupleId.
    final joinerDoc = await firestore.collection('users').doc(joinerUid).get();
    expect(joinerDoc.data()!['coupleId'], coupleId);

    // The couples doc is readable by a member (B is signed in) and lists both
    // partners creator-FIRST (architecture.md §3).
    final coupleDoc = await firestore.collection('couples').doc(coupleId).get();
    expect(coupleDoc.exists, isTrue);
    expect(coupleDoc.data()!['memberUids'], [creatorUid, joinerUid]);

    // --- A fresh third user redeeming the now-spent code is rejected with the
    // typed consumed exception (the invite is 'joined', so 'consumed' wins the
    // server's check order before profile-missing — C still gets a profile so
    // the assertion is unambiguously about the spent invite).
    final thirdUid = await switchTo({
      'sub': 'pair-third-uid',
      'email': 'third@example.com',
    });
    await profiles.saveProfile(thirdUid, profile);
    await expectLater(
      invites.joinInvite(code),
      throwsA(isA<InviteJoinConsumedException>()),
    );
  });
}
