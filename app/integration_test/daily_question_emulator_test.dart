// The M3.3 answer → mutual-reveal acceptance against the Auth + Firestore +
// Functions EMULATORS — device/simulator only (cloud_firestore/cloud_functions
// need platform channels; this cannot run in the plain `flutter test` VM).
//
// What this proves end-to-end that the per-PR suites cannot:
//   - the app's coupleDayKey (Dart mirror, stored timezone) addresses the SAME
//     doc a rollover-shaped admin write creates (the parity fixture pins the
//     function; this pins the round trip);
//   - the paired-home UI renders the REAL assigned question resolved from the
//     bundled pack (rootBundle works here — no fake-async zone);
//   - the reveal invariant against the REAL rules: the partner's answer listen
//     is DENIED pre-answer, streams post-answer, and both docs freeze once
//     both exist (the M3 accept line, live).
//
// "Two devices" is modeled as two users each on their OWN FirebaseApp instance
// (per-user Auth + Firestore + Functions wired to the emulators) — a truer
// two-devices shape than a mid-test auth switch, and the structural fix for
// ci-debt #36 (no signOut ever runs; see the note above the test body).
// The day doc is seeded through the firestore emulator's REST surface with the
// owner bearer token — the same rules bypass the admin SDK gives the rollover
// Function (client writes to days/ are rules-denied BY DESIGN, so the app
// cannot seed it itself).
//
// The functions emulator require()s functions/lib/index.js (it never compiles
// TS), so `npm run build` in functions/ must land first; the firestore
// emulator needs Java 21+ on PATH. Run (two terminals, repo root then app/):
//   npx firebase-tools emulators:start \
//     --only auth,firestore,functions --project demo-hayati
//   flutter test integration_test/daily_question_emulator_test.dart \
//     --dart-define=USE_AUTH_EMULATOR=true \
//     --dart-define=USE_FIRESTORE_EMULATOR=true \
//     --dart-define=USE_FUNCTIONS_EMULATOR=true \
//     -d <device>
//
// CI runs this suite on the main-only `integration-emulator` job (macOS
// runner; POST-MERGE signal — run locally before merging when possible).
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/firebase/firebase_bootstrap.dart';
import 'package:hayati_app/core/l10n/gen/app_localizations.dart';
import 'package:hayati_app/features/daily_question/data/asset_question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/data/firestore_couple_answers_repository.dart';
import 'package:hayati_app/features/daily_question/data/firestore_couple_day_repository.dart';
import 'package:hayati_app/features/daily_question/data/firestore_couple_repository.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_data_exception.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_screen.dart';
import 'package:hayati_app/features/pairing/data/functions_invite_repository.dart';
import 'package:hayati_app/features/profile/data/firestore_profile_repository.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The joiner's isolated FirebaseApp (user B). The default app is the creator
  // (user A). Bootstrapped in setUpAll, read in the test body, deleted last.
  late final FirebaseApp appB;

  setUpAll(() async {
    if (!kUseAuthEmulator || !kUseFirestoreEmulator || !kUseFunctionsEmulator) {
      fail(
        'This suite only runs against the emulators. Pass '
        '--dart-define=USE_AUTH_EMULATOR=true '
        '--dart-define=USE_FIRESTORE_EMULATOR=true '
        '--dart-define=USE_FUNCTIONS_EMULATOR=true (see file header).',
      );
    }
    // Same bootstrap as pairing_emulator_test.dart: the default app must carry
    // the EMULATOR project id (the functions emulator serves only demo-hayati)
    // and every dummy value must keep a natively-valid SHAPE.
    try {
      // --- User A (creator): the DEFAULT app. Its emulator wiring is what the
      // USE_*_EMULATOR dart-defines would steer, but this suite wires by hand.
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
      FirebaseFirestore.instance.useFirestoreEmulator(
        kAuthEmulatorHost,
        kFirestoreEmulatorPort,
      );
      FirebaseFunctions.instanceFor(
        region: kFunctionsRegion,
      ).useFunctionsEmulator(kAuthEmulatorHost, kFunctionsEmulatorPort);

      // --- User B (joiner): a NAMED secondary app. The dart-defines steer only
      // the default instance, so B's Auth + Firestore + Functions must be wired
      // to the emulators by hand — and BEFORE the test body touches instance B
      // (cloud_firestore 6.6.0 snapshots settings on first use, per-instance;
      // see firebase_bootstrap.dart). Guard against a duplicate-app on a re-run
      // in the same process (Firebase.initializeApp(name:) throws otherwise).
      if (Firebase.apps.any((app) => app.name == 'partnerB')) {
        appB = Firebase.app('partnerB');
      } else {
        appB = await Firebase.initializeApp(
          name: 'partnerB',
          options: const FirebaseOptions(
            apiKey: 'AIzaSyD-demo-hayati-emulator-0000000000',
            appId: '1:870954957461:ios:0000000000000000000000',
            messagingSenderId: '870954957461',
            projectId: 'demo-hayati',
            iosBundleId: 'com.hayati.app',
          ),
        );
        await FirebaseAuth.instanceFor(
          app: appB,
        ).useAuthEmulator(kAuthEmulatorHost, kAuthEmulatorPort);
        FirebaseFirestore.instanceFor(
          app: appB,
        ).useFirestoreEmulator(kAuthEmulatorHost, kFirestoreEmulatorPort);
        FirebaseFunctions.instanceFor(
          app: appB,
          region: kFunctionsRegion,
        ).useFunctionsEmulator(kAuthEmulatorHost, kFunctionsEmulatorPort);
      }
    } catch (error, stack) {
      fail('emulator bootstrap failed: $error\n$stack');
    }
  });

  // Awaits the first [stream] event satisfying [matches], then CANCELS the
  // subscription — the emitsThrough equivalent, but managed so no rules-checked
  // Firestore listen outlives its assertion into teardown (the ci-debt #36
  // hygiene invariant; a StreamQueue would pull in package:async, which is only
  // a transitive dep — depend_on_referenced_packages — so this uses a raw
  // StreamSubscription off dart:async instead).
  Future<void> expectEmitsThrough(
    Stream<Object?> stream,
    bool Function(Object? value) matches,
    String description, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<void>();
    final subscription = stream.listen(
      (value) {
        if (!completer.isCompleted && matches(value)) completer.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('stream closed before emitting $description'),
          );
        }
      },
    );
    try {
      await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  testWidgets(
    'answer → mutual reveal round trip: dayKey-addressed day doc, '
    'real question rendered, partner listen denied pre-answer, revealed '
    'post-answer, frozen once both exist',
    // De-quarantined (ci-debt #36 resolved): the round trip now runs as two
    // ISOLATED FirebaseApp instances — one user per app (creator on the default
    // app, joiner on the named 'partnerB' app), each with its own Auth +
    // Firestore + Functions. That is the structural fix the issue's diagnosis
    // recorded: with no mid-test signOut on a shared instance, no still-open
    // answers listen is ever re-evaluated as unauthenticated, so the
    // watchAnswer async* rethrow that used to land unhandled cannot occur. The
    // invariant itself also stays proven per-PR (rules mutation suite + the
    // functions race/e2e suites).
    (tester) async {
      // Delete the joiner app LAST (registered first → runs last under LIFO):
      // terminate its Firestore, then tear the app down, after every other
      // teardown (the http client below) has run.
      addTearDown(() async {
        await FirebaseFirestore.instanceFor(app: appB).terminate();
        await appB.delete();
      });

      // Two auth sessions, one per app — NEVER a mid-test signOut on either
      // instance: each user holds its own FirebaseApp for the whole test, so no
      // rules-checked listen is ever re-evaluated as unauthenticated. A signOut
      // on A or B would resurrect the exact ci-debt #36 hazard (a denied
      // still-open answers listen rethrowing unhandled out of watchAnswer's
      // async*).
      final authA = FirebaseAuth.instance; // creator — default app
      final authB = FirebaseAuth.instanceFor(app: appB); // joiner — partnerB
      final firestoreA = FirebaseFirestore.instance;
      final firestoreB = FirebaseFirestore.instanceFor(app: appB);
      final functionsA = FirebaseFunctions.instanceFor(
        region: kFunctionsRegion,
      );
      final functionsB = FirebaseFunctions.instanceFor(
        app: appB,
        region: kFunctionsRegion,
      );

      // Creator repos bind to instance A; joiner repos to instance B. Each user
      // signs in ONCE on its own instance and stays signed in for the whole
      // test (a fresh instance needs no prior signOut).
      final profilesA = FirestoreProfileRepository(firestore: firestoreA);
      final invitesA = FunctionsInviteRepository(); // default app resolves to A
      final answersA = FirestoreCoupleAnswersRepository(firestore: firestoreA);

      final profilesB = FirestoreProfileRepository(firestore: firestoreB);
      final invitesB = FunctionsInviteRepository(functions: functionsB);
      final couplesB = FirestoreCoupleRepository(firestore: firestoreB);
      final daysB = FirestoreCoupleDayRepository(firestore: firestoreB);
      final answersB = FirestoreCoupleAnswersRepository(firestore: firestoreB);

      Future<String> signInA(Map<String, Object?> claims) async {
        await authA.signInWithCredential(
          GoogleAuthProvider.credential(idToken: jsonEncode(claims)),
        );
        return authA.currentUser!.uid;
      }

      Future<String> signInB(Map<String, Object?> claims) async {
        await authB.signInWithCredential(
          GoogleAuthProvider.credential(idToken: jsonEncode(claims)),
        );
        return authB.currentUser!.uid;
      }

      // ADR-023 D4a: soloAnswers/couple-answers writes now require the writer to
      // carry a consent record. Record it via the real recordConsent callable
      // (the server stamps version + acceptedAt onto users/{uid}) for the
      // signed-in user — parameterized by the Functions instance so creator and
      // joiner each stamp consent as THEMSELVES on their own app.
      Future<void> recordConsent(FirebaseFunctions functions) async {
        await functions.httpsCallable('recordConsent').call<Object?>(
          <String, Object?>{'withdraw': false},
        );
      }

      const profile = RelationshipProfile(
        status: RelationshipStatus.married,
        contentLanguage: ContentLanguage.tr,
        register: ContentRegister.respectful,
      );

      // --- Pair A and B through the real join flow (the couple doc carries the
      // server-defaulted timezone the dayKey must key off). The creator signs
      // in once on instance A; the joiner once on instance B.
      final creatorUid = await signInA({
        'sub': 'daily-creator-uid',
        'email': 'daily-creator@example.com',
      });
      await profilesA.saveProfile(creatorUid, profile);
      await recordConsent(functionsA); // ADR-023 D4a precondition on answers
      final code = (await invitesA.createInvite()).code;

      final joinerUid = await signInB({
        'sub': 'daily-joiner-uid',
        'email': 'daily-joiner@example.com',
      });
      await profilesB.saveProfile(joinerUid, profile);
      await recordConsent(functionsB); // ADR-023 D4a precondition on answers
      final coupleId = await invitesB.joinInvite(code);

      final couple = (await couplesB.watchCouple(coupleId).first)!;
      expect(couple.memberUids, [creatorUid, joinerUid]);
      expect(couple.timezone, 'Europe/Istanbul'); // M2.3 join default

      // --- The app-side dayKey over the STORED zone (ADR-011). Seeding the day
      // doc at exactly this key and reading it back proves mirror & doc id
      // agree end-to-end (the parity fixture pins the pure function; this pins
      // the addressing).
      final dayKey = coupleDayKey(DateTime.now(), couple.timezone);

      // No day doc yet: the watch streams the honest null.
      expect(await daysB.watchDay(coupleId, dayKey).first, isNull);

      // --- Rollover-shaped ADMIN seed through the emulator's REST surface
      // (owner bearer = the admin-SDK rules bypass; client writes to days/ are
      // rules-denied by design — asserted below on instance B, a couple member).
      await expectLater(
        firestoreB
            .collection('couples')
            .doc(coupleId)
            .collection('days')
            .doc(dayKey)
            .set({'questionId': 'solo_tr_001'}),
        throwsA(isA<FirebaseException>()),
        reason: 'client day-doc writes must stay rules-denied',
      );
      final client = http.Client();
      addTearDown(client.close);
      final seedResponse = await client.patch(
        Uri.parse(
          'http://$kAuthEmulatorHost:$kFirestoreEmulatorPort/v1/projects/'
          'demo-hayati/databases/(default)/documents/couples/$coupleId/days/$dayKey',
        ),
        headers: {
          'Authorization': 'Bearer owner',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fields': {
            'questionId': {'stringValue': 'solo_tr_001'},
            'packId': {'stringValue': 'solo_tr'},
            'packVersion': {'integerValue': '1'},
            'assignedAt': {
              'timestampValue': DateTime.now().toUtc().toIso8601String(),
            },
          },
        }),
      );
      expect(
        seedResponse.statusCode,
        200,
        reason: 'admin day seed failed: ${seedResponse.body}',
      );

      // The member watch streams the assignment in (settled-state pattern —
      // never a one-shot racing the write; managed subscription, cancelled
      // once matched).
      await expectEmitsThrough(
        daysB.watchDay(coupleId, dayKey),
        (day) =>
            day != null &&
            (day as dynamic).questionId == 'solo_tr_001' &&
            (day as dynamic).packId == 'solo_tr',
        'the seeded solo_tr_001 assignment',
      );

      // The REAL question text this assignment resolves to (rootBundle works in
      // integration tests — no fake-async zone).
      const packs = AssetQuestionPackRepository();
      final pack = await packs.loadPack('solo_tr');
      final questionText = pack.questionById('solo_tr_001')!.text;
      expect(questionText, isNotEmpty);

      // --- THE INVARIANT, live: B has not answered, so B's listen on A's
      // (even-nonexistent) answer doc is DENIED by the rules.
      await expectLater(
        answersB.watchAnswer(coupleId, dayKey, creatorUid).first,
        throwsA(isA<CoupleDataPermissionException>()),
        reason: 'partner answer must be unreadable before own answer exists',
      );

      // --- B answers through the real write path (server-stamped answeredAt;
      // the rules accept exactly this shape).
      await answersB.saveAnswer(
        coupleId,
        dayKey,
        authorUid: joinerUid,
        questionId: 'solo_tr_001',
        text: 'Sabah kahvaltısında birlikte gülmemiz.',
      );
      await expectEmitsThrough(
        answersB.watchAnswer(coupleId, dayKey, joinerUid),
        (answer) => answer != null && (answer as dynamic).answeredAt != null,
        'own answer server-acked',
      );

      // Post-answer, the same partner read is permitted — and honestly null
      // (A has not answered).
      expect(
        await answersB.watchAnswer(coupleId, dayKey, creatorUid).first,
        isNull,
      );

      // --- The paired-home UI end-to-end over the REAL joiner (instance B)
      // repositories: the assigned question text renders, B's saved answer
      // seeds the entry, and the partner slot shows the waiting state.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coupleRepositoryProvider.overrideWith((ref) => couplesB),
            coupleDayRepositoryProvider.overrideWith((ref) => daysB),
            coupleAnswersRepositoryProvider.overrideWith((ref) => answersB),
            questionPackRepositoryProvider.overrideWith((ref) => packs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: PairedHomeScreen(uid: joinerUid, coupleId: coupleId),
          ),
        ),
      );
      // Real emulator round trips settle in wall-clock time; poll instead of a
      // single pumpAndSettle so a slow hop can't flake the run.
      final questionFinder = find.text(questionText);
      for (var i = 0; i < 100 && questionFinder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        questionFinder,
        findsOneWidget,
        reason: 'the paired home must render the real assigned question',
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.pairedPartnerWaiting),
        findsOneWidget,
        reason: 'own answer acked + partner unanswered = waiting slot',
      );
      expect(
        find.text('Sabah kahvaltısında birlikte gülmemiz.'),
        findsOneWidget,
        reason: "B's persisted answer seeds the entry",
      );
      // Unmount the screen deterministically so its live B-instance watches are
      // cancelled here (autodispose providers tear down on unmount), not left
      // dangling into teardown. No auth switch follows, so no settle/delay is
      // needed — the old signOut-race dance (ci-debt #36) is gone.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // --- A answers too: A is already signed in on instance A (no switch),
      // and once A's own answer exists A may watch B's doc — the reveal streams
      // in for A immediately.
      await answersA.saveAnswer(
        coupleId,
        dayKey,
        authorUid: creatorUid,
        questionId: 'solo_tr_001',
        text: 'Akşam yürüyüşümüz.',
      );
      await expectEmitsThrough(
        answersA.watchAnswer(coupleId, dayKey, joinerUid),
        (answer) =>
            answer != null &&
            (answer as dynamic).text ==
                'Sabah kahvaltısında birlikte gülmemiz.',
        "the partner's revealed answer text",
      );

      // --- Both exist: the rules freeze the pair — no post-reveal rewrites.
      // Issued as the writer (A) with A's own answer present, so the freeze is
      // hit for the right reason (commit-before-see).
      await expectLater(
        answersA.saveAnswer(
          coupleId,
          dayKey,
          authorUid: creatorUid,
          questionId: 'solo_tr_001',
          text: 'düzeltme denemesi',
        ),
        throwsA(isA<CoupleDataPermissionException>()),
        reason: 'answers must freeze once both exist (commit-before-see)',
      );
    },
  );
}
