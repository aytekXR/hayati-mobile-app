// Profile round-trip against the Auth + Firestore EMULATORS —
// device/simulator only (cloud_firestore needs platform channels; this
// cannot run in the plain `flutter test` VM, which is why it lives here).
//
// The Firestore emulator needs Java 21+ on PATH (firebase-tools 15.x).
// Run (two terminals, repo root then app/):
//   npx firebase-tools emulators:start --only auth,firestore --project demo-hayati
//   flutter test integration_test/profile_emulator_test.dart \
//     --dart-define=USE_AUTH_EMULATOR=true \
//     --dart-define=USE_FIRESTORE_EMULATOR=true \
//     -d <device>   # physical device needs
//                   # --dart-define=AUTH_EMULATOR_HOST=<host LAN IP>
//
// CI runs this suite on the main-only `integration-emulator` job (macOS runner +
// iOS simulator + auth/firestore emulators via `firebase emulators:exec`); see
// .github/workflows/ci.yml (ci-debt #6). It is a POST-MERGE signal, so run it
// locally (above) before merging, or trigger it on a branch with
// `gh workflow run ci.yml --ref <branch>`.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/features/profile/data/firestore_profile_repository.dart';
import 'package:hayati_app/features/profile/domain/profile_exception.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:integration_test/integration_test.dart';

const _profile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.respectful,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!kUseAuthEmulator || !kUseFirestoreEmulator) {
      fail(
        'This suite only runs against the emulators. Pass '
        '--dart-define=USE_AUTH_EMULATOR=true '
        '--dart-define=USE_FIRESTORE_EMULATOR=true (see file header).',
      );
    }
    await initializeFirebase(const AppConfig(flavor: AppFlavor.dev));
    // The Auth emulator accepts an unsigned JSON id_token (Session 003).
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: jsonEncode({
          'sub': 'profile-emulator-uid',
          'email': 'profile@example.com',
        }),
      ),
    );
  });

  testWidgets('profile save → watch round-trip with rules enforced', (
    tester,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final repository = FirestoreProfileRepository(
      firestore: FirebaseFirestore.instance,
    );

    // Fresh user: the first emission is the missing document.
    expect(await repository.watchProfile(uid).first, isNull);

    await repository.saveProfile(uid, _profile);
    // `emitsThrough`, not `.first`: saveProfile commits through a transaction,
    // which the server executes with no local latency compensation. A fresh
    // listener therefore emits the stale cached "no document" (null) before the
    // server snapshot lands. The app never sees that window — OnboardingGate
    // holds one long-lived subscription — but a listener opened per assertion
    // does, and `.first` would race it (observed red on the CI emulator leg).
    await expectLater(repository.watchProfile(uid), emitsThrough(_profile));

    // createdAt is server-stamped exactly once (create-once transaction).
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final createdAt = doc.data()!['createdAt'];
    expect(createdAt, isA<Timestamp>());

    await repository.saveProfile(
      uid,
      _profile.copyWith(register: ContentRegister.playful),
    );
    final rewritten = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    expect(rewritten.data()!['createdAt'], createdAt);
    expect(rewritten.data()!['register'], 'playful');
  });

  testWidgets('rules deny reading another user\'s profile', (tester) async {
    final repository = FirestoreProfileRepository(
      firestore: FirebaseFirestore.instance,
    );

    await expectLater(
      repository.watchProfile('someone-elses-uid').first,
      throwsA(isA<ProfilePermissionException>()),
    );
  });
}
