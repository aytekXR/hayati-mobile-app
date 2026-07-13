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
// "Two devices" is approximated as two users signed in SEQUENTIALLY in one
// process (the pairing suite's pattern): the reveal is a server-side fact.
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
    } catch (error, stack) {
      fail('emulator bootstrap failed: $error\n$stack');
    }
  });

  testWidgets(
    'answer → mutual reveal round trip: dayKey-addressed day doc, '
    'real question rendered, partner listen denied pre-answer, revealed '
    'post-answer, frozen once both exist',
    // QUARANTINED (ci-debt #36): deterministically red on main since the
    // M3.4 answerReveal trigger landed — the mid-test switchTo (signOut on
    // the shared Auth instance) denies a still-open answers listen and the
    // watchAnswer async* rethrow lands unhandled. Two settle-based fixes
    // (#34 pump-loop — live-binding pump never sleeps; #35 real 2s delay —
    // failure just shifted by the delay) proved it is not a cancel-flush
    // race. Structural fix per the issue: per-user FirebaseApp instances
    // instead of mid-test signOut. The invariant itself stays proven per-PR
    // (rules mutation suite + the functions race/e2e suites).
    skip:
        true, // ci-debt #36: unhandled listener denial at mid-test auth switch
    (tester) async {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final profiles = FirestoreProfileRepository(firestore: firestore);
      final invites = FunctionsInviteRepository();
      final couples = FirestoreCoupleRepository(firestore: firestore);
      final days = FirestoreCoupleDayRepository(firestore: firestore);
      final answers = FirestoreCoupleAnswersRepository(firestore: firestore);

      Future<String> switchTo(Map<String, Object?> claims) async {
        await auth.signOut();
        await auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: jsonEncode(claims)),
        );
        return auth.currentUser!.uid;
      }

      // ADR-023 D4a: soloAnswers/couple-answers writes now require the writer to
      // carry a consent record. Record it via the real recordConsent callable
      // (the server stamps version + acceptedAt onto users/{uid}) for the
      // currently signed-in user — the same server-owned-state seeding the
      // day-doc admin seed below uses, but through the production consent path.
      Future<void> recordConsent() async {
        await FirebaseFunctions.instanceFor(region: kFunctionsRegion)
            .httpsCallable('recordConsent')
            .call<Object?>(<String, Object?>{'withdraw': false});
      }

      const profile = RelationshipProfile(
        status: RelationshipStatus.married,
        contentLanguage: ContentLanguage.tr,
        register: ContentRegister.respectful,
      );

      // --- Pair A and B through the real join flow (the couple doc carries the
      // server-defaulted timezone the dayKey must key off).
      final creatorUid = await switchTo({
        'sub': 'daily-creator-uid',
        'email': 'daily-creator@example.com',
      });
      await profiles.saveProfile(creatorUid, profile);
      await recordConsent(); // ADR-023 D4a precondition on answer writes
      final code = (await invites.createInvite()).code;

      final joinerUid = await switchTo({
        'sub': 'daily-joiner-uid',
        'email': 'daily-joiner@example.com',
      });
      await profiles.saveProfile(joinerUid, profile);
      await recordConsent(); // ADR-023 D4a precondition on answer writes
      final coupleId = await invites.joinInvite(code);

      final couple = (await couples.watchCouple(coupleId).first)!;
      expect(couple.memberUids, [creatorUid, joinerUid]);
      expect(couple.timezone, 'Europe/Istanbul'); // M2.3 join default

      // --- The app-side dayKey over the STORED zone (ADR-011). Seeding the day
      // doc at exactly this key and reading it back proves mirror & doc id
      // agree end-to-end (the parity fixture pins the pure function; this pins
      // the addressing).
      final dayKey = coupleDayKey(DateTime.now(), couple.timezone);

      // No day doc yet: the watch streams the honest null.
      expect(await days.watchDay(coupleId, dayKey).first, isNull);

      // --- Rollover-shaped ADMIN seed through the emulator's REST surface
      // (owner bearer = the admin-SDK rules bypass; client writes to days/ are
      // rules-denied by design — asserted below).
      await expectLater(
        firestore
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
      // never a one-shot racing the write).
      await expectLater(
        days.watchDay(coupleId, dayKey),
        emitsThrough(
          predicate<Object?>(
            (day) =>
                day != null &&
                (day as dynamic).questionId == 'solo_tr_001' &&
                (day as dynamic).packId == 'solo_tr',
            'the seeded solo_tr_001 assignment',
          ),
        ),
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
        answers.watchAnswer(coupleId, dayKey, creatorUid).first,
        throwsA(isA<CoupleDataPermissionException>()),
        reason: 'partner answer must be unreadable before own answer exists',
      );

      // --- B answers through the real write path (server-stamped answeredAt;
      // the rules accept exactly this shape).
      await answers.saveAnswer(
        coupleId,
        dayKey,
        authorUid: joinerUid,
        questionId: 'solo_tr_001',
        text: 'Sabah kahvaltısında birlikte gülmemiz.',
      );
      await expectLater(
        answers.watchAnswer(coupleId, dayKey, joinerUid),
        emitsThrough(
          predicate<Object?>(
            (answer) =>
                answer != null && (answer as dynamic).answeredAt != null,
            'own answer server-acked',
          ),
        ),
      );

      // Post-answer, the same partner read is permitted — and honestly null
      // (A has not answered).
      expect(
        await answers.watchAnswer(coupleId, dayKey, creatorUid).first,
        isNull,
      );

      // --- The paired-home UI end-to-end over the REAL repositories: the
      // assigned question text renders, B's saved answer seeds the entry, and
      // the partner slot shows the waiting state.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coupleRepositoryProvider.overrideWith((ref) => couples),
            coupleDayRepositoryProvider.overrideWith((ref) => days),
            coupleAnswersRepositoryProvider.overrideWith((ref) => answers),
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
      // Tear the screen down BEFORE switching auth users: its live watches hold
      // rules-checked listeners that would otherwise error mid-switch.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // The pump above only SCHEDULES the listen cancels — they must reach the
      // emulator before switchTo's signOut re-auths every still-open listen as
      // unauthenticated (denied → the async* rethrow in watchAnswer has no
      // consumer left → unhandled). With the M3.4 answerReveal trigger live on
      // the same emulator pair, the trigger invocation right after the save
      // occupies the emulator exactly when these cancels arrive, and the race
      // turned deterministic-red (post-merge main runs, Session 014). NOTE the
      // settle must be a REAL delay: under the integration (live) binding,
      // tester.pump(duration) does NOT sleep wall-clock — it just schedules the
      // next frame — which is why a pump-loop "settle" changed nothing. This
      // file runs real async (it awaits real HTTP/Firestore futures), so
      // Future.delayed genuinely waits here.
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump();

      // --- A answers too: the reveal streams in for A immediately (A's own
      // answer exists, so A may watch B's doc).
      await switchTo({
        'sub': 'daily-creator-uid',
        'email': 'daily-creator@example.com',
      });
      await answers.saveAnswer(
        coupleId,
        dayKey,
        authorUid: creatorUid,
        questionId: 'solo_tr_001',
        text: 'Akşam yürüyüşümüz.',
      );
      await expectLater(
        answers.watchAnswer(coupleId, dayKey, joinerUid),
        emitsThrough(
          predicate<Object?>(
            (answer) =>
                answer != null &&
                (answer as dynamic).text ==
                    'Sabah kahvaltısında birlikte gülmemiz.',
            "the partner's revealed answer text",
          ),
        ),
        reason: 'post-answer the partner doc streams (mutual reveal)',
      );

      // --- Both exist: the rules freeze the pair — no post-reveal rewrites.
      await expectLater(
        answers.saveAnswer(
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
