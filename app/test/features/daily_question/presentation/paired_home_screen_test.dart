import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/core/widgets/seed_vessel.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/coach/domain/coach_repository_provider.dart';
import 'package:hayati_app/features/coach/presentation/coach_screen.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answer.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_data_exception.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_assignment.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_screen.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/pack_selection_screen.dart';
import 'package:hayati_app/features/entitlements/presentation/paywall_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_coach_repository.dart';
import '../../../support/fake_couple_answers_repository.dart';
import '../../../support/fake_couple_day_repository.dart';
import '../../../support/fake_couple_repository.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/fake_local_flag_store.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/fake_question_pack_repository.dart';
import '../../../support/localized_app.dart';

const coupleId = 'couple-1';
const ownUid = 'uid-1';
const partnerUid = 'uid-2';

/// Turkey is a permanent UTC+3 zone (no DST since 2016), so the paired home
/// keys the day off the STORED zone (ADR-011), never the device zone.
const istanbul = 'Europe/Istanbul';

/// The pinned wall clock: 09:00 UTC = 12:00 in Istanbul on 2026-07-10, so
/// [coupleDayKey] over the stored zone lands on [todayKey]. Every test is
/// clock-independent (verified against the couple_day_key parity fixture).
final fixedNow = DateTime.utc(2026, 7, 10, 9);
const todayKey = '20260710';

/// The generic by-id pack the rollover assigned from. Predictable texts —
/// `"EN paired question 1"` — so finds stay literal and never depend on the
/// shipped content (pinned separately by the asset repository tests).
const packId = 'paired_en';
const pairedPack = QuestionPack(
  packId: packId,
  version: 3,
  language: ContentLanguage.en,
  register: QuestionRegister.respectful,
  questions: [
    Question(
      id: 'paired_en_001',
      category: QuestionCategory.deep,
      depth: 3,
      text: 'EN paired question 1',
    ),
    Question(
      id: 'paired_en_002',
      category: QuestionCategory.fun,
      depth: 1,
      text: 'EN paired question 2',
    ),
  ],
);

/// The day doc's assignment metadata (points at [pairedPack]'s first
/// question). const, so it can seed the fake's initial store directly.
const defaultAssignment = CoupleDayAssignment(
  questionId: 'paired_en_001',
  packId: packId,
  packVersion: 3,
);

/// A server-acked own answer — [CoupleAnswer.answeredAt] non-null is the
/// commit ack the partner-slot gate waits out (a pending serverTimestamp
/// echo crosses as null and stays Locked).
CoupleAnswer ackedAnswer(String text, {String questionId = 'paired_en_001'}) =>
    CoupleAnswer(
      questionId: questionId,
      text: text,
      answeredAt: FakeCoupleAnswersRepository.answeredAtStamp,
    );

/// An entitled, unexpired mirror for [coupleId] against [fixedNow] (the clock
/// isPremium's expiry check reads).
FakeEntitlementRepository premiumMirror() => FakeEntitlementRepository(
  initialMirrors: {
    coupleId: CoupleEntitlement(
      entitled: true,
      expiresAt: fixedNow.add(const Duration(days: 30)),
    ),
  },
);

void main() {
  final en = l10nFor(const Locale('en'));
  // ADR-051's announcement is asserted in Arabic too: the direction it carries
  // is the one bidi property (ADR-033) no golden can see, because an
  // announcement is never drawn.
  final ar = l10nFor(const Locale('ar'));

  Future<
    ({
      FakeCoupleRepository couples,
      FakeCoupleDayRepository days,
      FakeCoupleAnswersRepository answers,
      FakeQuestionPackRepository packs,
      FakeEntitlementRepository entitlements,
    })
  >
  pumpPaired(
    WidgetTester tester, {
    String timezone = istanbul,
    Couple? couple,
    bool seedCouple = true,
    CoupleDayAssignment assignment = defaultAssignment,
    bool seedDay = true,
    Map<String, CoupleAnswer>? initialAnswers,
    bool seedDefaultPack = true,
    DateTime? now,
    DateTime Function()? clock,
    // The couple's entitlement mirror — an empty (free) mirror is the explicit
    // default (ADR-014: explicit > incidental) so the packs tile reads a real
    // `isPremium` false rather than the un-overridden throw→AsyncError path.
    FakeEntitlementRepository? entitlements,
    Future<void> Function(
      String coupleId,
      String dayKey,
      String authorUid,
      String questionId,
      String text,
    )?
    onSaveAnswer,
    Future<QuestionPack> Function(String packId)? onLoadPack,
    Locale locale = const Locale('en'),
    // Forces MediaQuery.disableAnimations for the reduce-motion reveal test —
    // the soft unfold must collapse to an instant, animation-free appearance.
    bool reduceMotion = false,
  }) async {
    final coupleDoc =
        couple ??
        Couple(
          id: coupleId,
          memberUids: const [ownUid, partnerUid],
          timezone: timezone,
        );
    final couples = FakeCoupleRepository(
      initialCouples: seedCouple ? {coupleId: coupleDoc} : null,
    );
    final days = FakeCoupleDayRepository(
      initialDays: seedDay
          ? {FakeCoupleDayRepository.keyFor(coupleId, todayKey): assignment}
          : null,
    );
    final answers = FakeCoupleAnswersRepository(initialAnswers: initialAnswers)
      ..onSaveAnswer = onSaveAnswer;
    final packs = FakeQuestionPackRepository()..onLoadPack = onLoadPack;
    if (seedDefaultPack) packs.seedPack(pairedPack);
    final mirrors = entitlements ?? FakeEntitlementRepository();
    // Signed-in auth so the pushed PackSelectionScreen's auth listen resolves;
    // inert for tests that never push it (PairedHomeScreen ignores auth).
    final auth = FakeAuthRepository(initialUser: const AuthUser(uid: ownUid));
    addTearDown(couples.dispose);
    addTearDown(days.dispose);
    addTearDown(answers.dispose);
    addTearDown(mirrors.dispose);
    addTearDown(auth.dispose);
    // The clock seam: a mutable holder (`clock`) drives the app-resume re-key;
    // everything else pins a fixed instant. The same clock backs isPremium's
    // expiry check, so a premium mirror needs a future expiry against it.
    final clockFn = clock ?? (() => now ?? fixedNow);
    const paired = PairedHomeScreen(uid: ownUid, coupleId: coupleId);
    final home = reduceMotion
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: paired,
            ),
          )
        : paired;
    await tester.pumpWidget(
      localizedApp(
        home,
        locale: locale,
        overrides: [
          coupleRepositoryProvider.overrideWith((ref) => couples),
          coupleDayRepositoryProvider.overrideWith((ref) => days),
          coupleAnswersRepositoryProvider.overrideWith((ref) => answers),
          questionPackRepositoryProvider.overrideWith((ref) => packs),
          entitlementRepositoryProvider.overrideWith((ref) => mirrors),
          authRepositoryProvider.overrideWith((ref) => auth),
          soloClockProvider.overrideWith((ref) => clockFn),
          // The premium coach tile can push CoachScreen, which resolves the
          // coach seams (inert for every non-coach test — the tile is gated).
          localFlagStoreProvider.overrideWithValue(FakeLocalFlagStore()),
          coachRepositoryProvider.overrideWith((ref) => FakeCoachRepository()),
          profileRepositoryProvider.overrideWith(
            (ref) => FakeProfileRepository(),
          ),
        ],
      ),
    );
    return (
      couples: couples,
      days: days,
      answers: answers,
      packs: packs,
      entitlements: mirrors,
    );
  }

  group('loading', () {
    testWidgets('shows a spinner until the couple stream emits', (
      tester,
    ) async {
      await pumpPaired(tester);

      // async* streams need a microtask to emit; before that: loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('EN paired question 1'), findsOneWidget);
    });
  });

  group('error states', () {
    testWidgets('a couple network failure shows retryable copy, and retry '
        'resubscribes and recovers', (tester) async {
      final fakes = await pumpPaired(tester);
      await tester.pumpAndSettle();
      expect(find.text('EN paired question 1'), findsOneWidget);

      fakes.couples.emitError(
        coupleId,
        const CoupleDataNetworkException(message: 'off'),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.errorNetworkRetry), findsOneWidget);
      // textContaining, not text: a bidi-isolated render wraps the string in
      // U+2068/U+2069, and find.text is exact-match — so this row would go
      // green whether the content was absent OR merely isolated. Under the
      // conditional seam this cell is LTR and stays pristine, but a
      // findsNothing that CANNOT fail is worse than no row at all
      // (ADR-033 D8, addendum 47).
      expect(find.textContaining('EN paired question 1'), findsNothing);

      // The fake replays the (still-seeded) couple on re-listen.
      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();
      expect(find.text('EN paired question 1'), findsOneWidget);
    });

    testWidgets('a missing couple doc (corrupt users.coupleId) is the generic '
        'error, not a crash', (tester) async {
      await pumpPaired(tester, seedCouple: false);
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a couple this uid is not a member of is the generic error '
        '(partnerUidFor null)', (tester) async {
      await pumpPaired(
        tester,
        couple: const Couple(
          id: coupleId,
          memberUids: [partnerUid, 'uid-3'],
          timezone: istanbul,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
    });

    testWidgets('a stored zone the tz db cannot resolve is the generic error, '
        'never a red-screen throw into build', (tester) async {
      await pumpPaired(tester, timezone: 'Not/AZone');
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('no-day-yet and pack lag', () {
    testWidgets('no assignment shows the honest no-day-yet state (no retry), '
        'and the question streams in live', (tester) async {
      final fakes = await pumpPaired(tester, seedDay: false);
      await tester.pumpAndSettle();

      expect(find.text(en.pairedNoDayTitle), findsOneWidget);
      expect(find.text(en.pairedNoDayBody), findsOneWidget);
      // The day watch is live — the server is authoritative, so no retry
      // affordance here.
      expect(find.text(en.tryAgain), findsNothing);

      fakes.days.emitDay(coupleId, todayKey, defaultAssignment);
      await tester.pumpAndSettle();
      expect(find.text('EN paired question 1'), findsOneWidget);
    });

    testWidgets('an assignment referencing an unbundled packId is the '
        'update-the-app state', (tester) async {
      await pumpPaired(
        tester,
        assignment: const CoupleDayAssignment(
          questionId: 'paired_en_001',
          packId: 'paired_en_v99',
          packVersion: 99,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.pairedPackUpdateTitle), findsOneWidget);
      expect(find.text(en.pairedPackUpdateBody), findsOneWidget);
    });

    testWidgets('an assignment whose questionId is absent from the bundled '
        'pack is the same update-the-app state', (tester) async {
      await pumpPaired(
        tester,
        assignment: const CoupleDayAssignment(
          questionId: 'paired_en_999',
          packId: packId,
          packVersion: 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.pairedPackUpdateTitle), findsOneWidget);
    });
  });

  group('answer entry', () {
    testWidgets('an unanswered day shows the question, the entry field, and a '
        'save button gated on non-empty text', (tester) async {
      await pumpPaired(tester);
      await tester.pumpAndSettle();

      expect(find.text('EN paired question 1'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(en.pairedPartnerLocked), findsOneWidget);

      final saveButton = find.widgetWithText(FilledButton, en.pairedAnswerSave);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'A shared sunrise.');
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });

    testWidgets('saving writes exactly the trimmed text bound to the day\'s '
        'question, shows the saved caption, and flips the slot to waiting', (
      tester,
    ) async {
      final fakes = await pumpPaired(tester);
      await tester.pumpAndSettle();
      expect(find.text(en.pairedPartnerLocked), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A shared sunrise.  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, en.pairedAnswerSave));
      await tester.pumpAndSettle();

      expect(fakes.answers.saveCalls, 1);
      expect(fakes.answers.savedTexts, ['A shared sunrise.']);
      expect(fakes.answers.savedQuestionIds, ['paired_en_001']);
      // The acked echo streams back through the answer watch.
      expect(find.text(en.pairedAnswerSavedCaption), findsOneWidget);
      expect(find.text(en.pairedPartnerLocked), findsNothing);
      expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
    });

    testWidgets('a save failure surfaces honest inline copy and keeps the '
        'entry editable; a later success clears it', (tester) async {
      final fakes = await pumpPaired(
        tester,
        onSaveAnswer: (coupleId, dayKey, authorUid, questionId, text) async {
          throw const CoupleDataNetworkException(message: 'off');
        },
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Will fail first.');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, en.pairedAnswerSave));
      await tester.pumpAndSettle();

      expect(find.text(en.errorNetworkRetry), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, en.pairedAnswerSave);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);

      // The next save succeeds (default persist+ack) and clears the error.
      fakes.answers.onSaveAnswer = null;
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text(en.errorNetworkRetry), findsNothing);
      expect(find.text(en.pairedAnswerSavedCaption), findsOneWidget);
    });
  });

  group('mutual reveal', () {
    testWidgets('the partner answering later flips the slot to revealed and '
        'collapses the entry into the read-only own card', (tester) async {
      final fakes = await pumpPaired(
        tester,
        initialAnswers: {
          FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
              ackedAnswer('My own thoughts.'),
        },
      );
      await tester.pumpAndSettle();

      // Own answered, partner not yet: waiting, entry still editable.
      expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      fakes.answers.emitAnswer(
        coupleId,
        todayKey,
        partnerUid,
        ackedAnswer('Partner reply here.'),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.pairedPartnerAnswerLabel), findsOneWidget);
      expect(find.text('Partner reply here.'), findsOneWidget);
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      // Rules freeze both docs on reveal — the entry is gone.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('both answers pre-seeded reveals immediately', (tester) async {
      await pumpPaired(
        tester,
        initialAnswers: {
          FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
              ackedAnswer('My own thoughts.'),
          FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, partnerUid):
              ackedAnswer('Partner reply here.'),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      expect(find.text(en.pairedPartnerAnswerLabel), findsOneWidget);
      expect(find.text('Partner reply here.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a partner-watch permission denial after the own ack renders '
        'Locked (defense-in-depth), then the bounded retry self-heals', (
      tester,
    ) async {
      final fakes = await pumpPaired(
        tester,
        initialAnswers: {
          FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
              ackedAnswer('My own thoughts.'),
          FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, partnerUid):
              ackedAnswer('Partner reply here.'),
        },
      );
      await tester.pumpAndSettle();
      // Both seeded → revealed.
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);

      // A lost exists()-race denies the partner listen: the client maps the
      // permission error back to Locked, never an error card.
      fakes.answers.emitError(
        coupleId,
        todayKey,
        partnerUid,
        const CoupleDataPermissionException(message: 'denied'),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.pairedPartnerLocked), findsOneWidget);

      // The bounded permission-only retry (1s) resubscribes; the fake replays
      // the stored partner answer → the slot self-heals to revealed. Flushing
      // the timer here also clears the pending-Timer trap.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(en.pairedPartnerAnswerLabel), findsOneWidget);
      expect(find.text('Partner reply here.'), findsOneWidget);
    });
  });

  group('lifecycle', () {
    testWidgets('foregrounding past the couple\'s midnight re-keys to the new '
        'day (nothing seeded there → no-day-yet)', (tester) async {
      var now = fixedNow; // Istanbul 2026-07-10 → todayKey.
      await pumpPaired(tester, clock: () => now);
      await tester.pumpAndSettle();
      expect(find.text('EN paired question 1'), findsOneWidget);

      // Cross the couple's midnight: 00:00 UTC 2026-07-11 = 03:00 Istanbul →
      // dayKey 20260711, which nothing is seeded for.
      now = DateTime.utc(2026, 7, 11);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(en.pairedNoDayTitle), findsOneWidget);
      // textContaining, not text: a bidi-isolated render wraps the string in
      // U+2068/U+2069, and find.text is exact-match — so this row would go
      // green whether the content was absent OR merely isolated. Under the
      // conditional seam this cell is LTR and stays pristine, but a
      // findsNothing that CANNOT fail is worse than no row at all
      // (ADR-033 D8, addendum 47).
      expect(find.textContaining('EN paired question 1'), findsNothing);
    });
  });

  group('streak strip (redesign ui-ux §6.3 — the seed vessel)', () {
    // A couple carrying a positive server streak (ADR-012). The strip is
    // ALWAYS present on the question view since the redesign (the vessel
    // carries the streak language in every state); a zero count renders the
    // empty vessel + the canonical honest line, never a fake streak.
    Couple coupleWithStreak(int count, {int graceTokens = 1}) => Couple(
      id: coupleId,
      memberUids: const [ownUid, partnerUid],
      timezone: istanbul,
      streak: CoupleStreak(
        count: count,
        lastMutualDate: '20260709',
        graceTokens: graceTokens,
      ),
    );

    Map<String, CoupleAnswer> bothAnswered() => {
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
          ackedAnswer('My own thoughts.'),
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, partnerUid):
          ackedAnswer('Partner reply here.'),
    };

    testWidgets('revealed with count > 0 shows the seeds/days line beside the '
        'vessel (the Material heart is retired)', (tester) async {
      await pumpPaired(
        tester,
        couple: coupleWithStreak(4),
        initialAnswers: bothAnswered(),
      );
      await tester.pumpAndSettle();

      // Sanity: we are in the revealed state.
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      expect(find.text(en.streakSeeds(4)), findsOneWidget);
      expect(find.byType(SeedVessel), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('revealed under a PREMIUM mirror renders the strip '
        'identically (never hidden for premium)', (tester) async {
      await pumpPaired(
        tester,
        couple: coupleWithStreak(4),
        initialAnswers: bothAnswered(),
        entitlements: premiumMirror(),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      expect(find.text(en.streakSeeds(4)), findsOneWidget);
      expect(find.byType(SeedVessel), findsOneWidget);
    });

    testWidgets('revealed with the zero streak shows the empty vessel + the '
        'canonical empty line — never a zero count (honest display: trigger '
        'lag must not show a streak)', (tester) async {
      // Default couple = CoupleStreak.zero (count 0).
      await pumpPaired(tester, initialAnswers: bothAnswered());
      await tester.pumpAndSettle();

      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      expect(find.text(en.streakVesselEmpty), findsOneWidget);
      // The count line must never render a zero (guards a `>= 0` regression).
      expect(find.text(en.streakSeeds(0)), findsNothing);
      expect(find.byType(SeedVessel), findsOneWidget);
    });

    testWidgets('locked (pre-answer) SHOWS the strip — the vessel is the '
        'always-present streak language since the redesign', (tester) async {
      await pumpPaired(tester, couple: coupleWithStreak(4));
      await tester.pumpAndSettle();

      expect(find.text(en.pairedPartnerLocked), findsOneWidget);
      expect(find.text(en.streakSeeds(4)), findsOneWidget);
      expect(find.byType(SeedVessel), findsOneWidget);
    });

    testWidgets('waiting (own answered, partner not) shows the strip', (
      tester,
    ) async {
      await pumpPaired(
        tester,
        couple: coupleWithStreak(4),
        initialAnswers: {
          FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
              ackedAnswer('My own thoughts.'),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
      expect(find.text(en.streakSeeds(4)), findsOneWidget);
    });

    testWidgets('a spent grace token (graceTokens == 0) surfaces the mercy '
        'caption in the strip', (tester) async {
      await pumpPaired(
        tester,
        couple: coupleWithStreak(4, graceTokens: 0),
        initialAnswers: bothAnswered(),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.streakMercyUsed), findsOneWidget);
    });

    testWidgets('an available grace token stays silent — no mercy caption', (
      tester,
    ) async {
      await pumpPaired(
        tester,
        couple: coupleWithStreak(4),
        initialAnswers: bothAnswered(),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.streakMercyUsed), findsNothing);
    });

    testWidgets('no-day-yet carries no strip (the vessel lives on the '
        'question view only)', (tester) async {
      await pumpPaired(tester, couple: coupleWithStreak(4), seedDay: false);
      await tester.pumpAndSettle();

      expect(find.text(en.pairedNoDayTitle), findsOneWidget);
      expect(find.byType(SeedVessel), findsNothing);
      expect(find.text(en.streakSeeds(4)), findsNothing);
    });
  });

  group('locale', () {
    testWidgets('renders RTL under an Arabic locale', (tester) async {
      await pumpPaired(tester, locale: const Locale('ar'));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(PairedHomeScreen))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('packs tile (M4.2)', () {
    Map<String, CoupleAnswer> bothAnswered() => {
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
          ackedAnswer('My own thoughts.'),
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, partnerUid):
          ackedAnswer('Partner reply here.'),
    };

    testWidgets('renders on the question view with the free subtitle + lock '
        'when free', (tester) async {
      // Revealed: the partner slot is an answer card (no lock of its own), so
      // the only lock icon on screen is the tile's free-tier badge.
      await pumpPaired(tester, initialAnswers: bothAnswered());
      await tester.pumpAndSettle();

      expect(find.text(en.packsTileTitle), findsOneWidget);
      expect(find.text(en.packsTileSubtitleFree), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('drops the lock and shows the premium subtitle when premium', (
      tester,
    ) async {
      await pumpPaired(
        tester,
        entitlements: premiumMirror(),
        initialAnswers: bothAnswered(),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.packsTileSubtitlePremium), findsOneWidget);
      expect(find.text(en.packsTileSubtitleFree), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('is ABSENT in the no-day-yet state', (tester) async {
      await pumpPaired(tester, seedDay: false);
      await tester.pumpAndSettle();

      expect(find.text(en.pairedNoDayTitle), findsOneWidget);
      expect(find.text(en.packsTileTitle), findsNothing);
    });

    testWidgets('tapping the tile pushes the pack selection screen', (
      tester,
    ) async {
      await pumpPaired(tester, initialAnswers: bothAnswered());
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.packsTileTitle));
      await tester.pumpAndSettle();

      expect(find.byType(PackSelectionScreen), findsOneWidget);
    });
  });

  group('free tier untouched (M4.2 probes)', () {
    testWidgets('the question card, entry, and slot render identically free vs '
        'premium', (tester) async {
      // Free.
      await pumpPaired(tester);
      await tester.pumpAndSettle();
      expect(find.text('EN paired question 1'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(en.pairedPartnerLocked), findsOneWidget);

      // Premium — the same finders hold (only the tile subtitle/lock differ).
      await pumpPaired(tester, entitlements: premiumMirror());
      await tester.pumpAndSettle();
      expect(find.text('EN paired question 1'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(en.pairedPartnerLocked), findsOneWidget);
    });

    testWidgets('the answer save flow completes with isPremium false', (
      tester,
    ) async {
      final fakes = await pumpPaired(tester); // free mirror
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A shared sunrise.  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, en.pairedAnswerSave));
      await tester.pumpAndSettle();

      expect(fakes.answers.saveCalls, 1);
      expect(fakes.answers.savedTexts, ['A shared sunrise.']);
      expect(find.text(en.pairedAnswerSavedCaption), findsOneWidget);
      expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
      // No paywall interstitial appeared in the loop.
      expect(find.byType(PaywallScreen), findsNothing);
    });

    testWidgets('NO PaywallScreen is ever pushed while driving the full answer '
        'flow (the interstitial probe)', (tester) async {
      await pumpPaired(tester); // free
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);

      await tester.enterText(find.byType(TextField), 'A shared sunrise.');
      await tester.pump();
      expect(find.byType(PaywallScreen), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, en.pairedAnswerSave));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);
    });

    testWidgets('NO CoachScreen is ever pushed while driving the full answer '
        'flow (free-tier zero coach surface, ADR-017 D1)', (tester) async {
      await pumpPaired(tester); // free
      await tester.pumpAndSettle();
      expect(find.byType(CoachScreen), findsNothing);
      expect(find.text(en.coachTileTitle), findsNothing);

      await tester.enterText(find.byType(TextField), 'A shared sunrise.');
      await tester.pump();
      expect(find.byType(CoachScreen), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, en.pairedAnswerSave));
      await tester.pumpAndSettle();
      expect(find.byType(CoachScreen), findsNothing);
    });
  });

  group('coach tile (M5.2)', () {
    Map<String, CoupleAnswer> bothAnswered() => {
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
          ackedAnswer('My own thoughts.'),
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, partnerUid):
          ackedAnswer('Partner reply here.'),
    };

    testWidgets('is ABSENT for a free couple — zero coach surface (no tile, no '
        'spacer) anywhere in the question view', (tester) async {
      await pumpPaired(tester, initialAnswers: bothAnswered());
      await tester.pumpAndSettle();

      // The question view is up (revealed) — but the coach renders nothing.
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      expect(find.text(en.coachTileTitle), findsNothing);
      expect(find.text(en.coachTileSubtitle), findsNothing);
      expect(find.byIcon(Icons.forum_outlined), findsNothing);
    });

    testWidgets('renders for a premium couple with its title + subtitle', (
      tester,
    ) async {
      await pumpPaired(
        tester,
        entitlements: premiumMirror(),
        initialAnswers: bothAnswered(),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.coachTileTitle), findsOneWidget);
      expect(find.text(en.coachTileSubtitle), findsOneWidget);
    });

    testWidgets('tapping the coach tile pushes the coach screen', (
      tester,
    ) async {
      await pumpPaired(
        tester,
        entitlements: premiumMirror(),
        initialAnswers: bothAnswered(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.coachTileTitle));
      await tester.pumpAndSettle();

      expect(find.byType(CoachScreen), findsOneWidget);
    });

    testWidgets('the live mirror flips the coach tile BOTH directions: free → '
        'premium (tile appears) → past-expiry downgrade (tile disappears)', (
      tester,
    ) async {
      final fakes = await pumpPaired(tester, initialAnswers: bothAnswered());
      await tester.pumpAndSettle();
      expect(find.text(en.coachTileTitle), findsNothing);

      // The webhook writes an entitled, unexpired mirror → the tile appears.
      fakes.entitlements.emit(
        coupleId,
        CoupleEntitlement(
          entitled: true,
          expiresAt: fixedNow.add(const Duration(days: 30)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.coachTileTitle), findsOneWidget);

      // A delayed EXPIRATION (entitled:true, expiresAt past) downgrades through
      // the real isPremium expiry check → the tile disappears again.
      fakes.entitlements.emit(
        coupleId,
        CoupleEntitlement(
          entitled: true,
          expiresAt: fixedNow.subtract(const Duration(minutes: 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.coachTileTitle), findsNothing);
    });
  });

  // The signature reveal interaction, staged as the redesign's three-beat
  // choreography (ui-ux §11): unfold-toward → settle-pair (the single light
  // haptic fires AT the settle, 480ms in — no longer the instant the slot
  // flips) → seed-drop. The choreography is TRANSIENT — no golden captures it,
  // so it is proven here (the S028 lesson: a fix on a transient surface needs
  // a widget test, not a golden); the beat mechanics themselves are pinned by
  // reveal_choreography_test.dart, this group proves the paired-home WIRING
  // (live transition, cold-open bound, at-most-once haptic, reduce-motion).
  //
  // These tests deliberately drive frames with pump()/pump(Duration) rather
  // than pumpAndSettle: the reveal ANIMATION is the thing under test, so
  // settling it away would hide the mid-fade frame.
  group('reveal choreography + haptic (ui-ux §11)', () {
    List<MethodCall> spyHaptics(WidgetTester tester) {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return haptics;
    }

    // The HEARD half of the reveal (ADR-051, #174). `SemanticsService`
    // .sendAnnouncement posts an AnnounceSemanticsEvent to
    // SystemChannels.accessibility — a BasicMessageChannel, so it needs the
    // DECODED-message mock, not the method-call one `spyHaptics` uses.
    //
    // ⚠️ Asserting "a liveRegion node exists" would be the vacuous version of
    // this test, and #174 says so in those words. What is asserted here is the
    // EVENT: that it is dispatched, once, with the right text and the right
    // direction.
    List<Map<Object?, Object?>> spyAnnouncements(WidgetTester tester) {
      final announcements = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message! as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              announcements.add(map['data']! as Map<Object?, Object?>);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      return announcements;
    }

    // Pumps a bounded number of frames until [finder] matches — the read chain
    // (answer stream → partnerSlotProvider → rebuild) settles over a few
    // microtask hops. Bare pump()s elapse zero fake time, so a mounted unfold
    // stays at its start value, leaving the mid-fade assertion meaningful.
    Future<void> pumpUntil(
      WidgetTester tester,
      Finder finder, {
      int maxPumps = 12,
    }) async {
      for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
        await tester.pump();
      }
    }

    // Finish the 900ms three-beat choreography deterministically without
    // pumpAndSettle, so no ticker is left pending at teardown.
    Future<void> settleUnfold(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 1000));

    // Advance from the choreography's mount past beat 2's settle (480ms) —
    // the moment the haptic fires — without finishing beat 3.
    Future<void> pumpPastSettle(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 500));

    Map<String, CoupleAnswer> ownOnly() => {
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
          ackedAnswer('My own thoughts.'),
    };
    Map<String, CoupleAnswer> bothAnswered() => {
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, ownUid):
          ackedAnswer('My own thoughts.'),
      FakeCoupleAnswersRepository.keyFor(coupleId, todayKey, partnerUid):
          ackedAnswer('Partner reply here.'),
    };

    testWidgets('the revealed group crossfades in (opacity climbs 0→1) on the '
        'live waiting→revealed transition', (tester) async {
      final fakes = await pumpPaired(tester, initialAnswers: ownOnly());
      await tester.pumpAndSettle(); // waiting: no unfold yet → settles cleanly
      expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
      expect(find.byKey(revealUnfoldOpacityKey), findsNothing);

      fakes.answers.emitAnswer(
        coupleId,
        todayKey,
        partnerUid,
        ackedAnswer('Partner reply here.'),
      );
      // Propagate the partner answer and mount the choreography at its START.
      await pumpUntil(tester, find.byKey(revealUnfoldOpacityKey));
      expect(find.byKey(revealUnfoldOpacityKey), findsOneWidget);

      // Partway through beat 1 (300ms): mid-fade — proof the animation is
      // actually running, not frozen at either boundary.
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.widget<Opacity>(find.byKey(revealUnfoldOpacityKey));
      expect(mid.opacity, greaterThan(0.0));
      expect(mid.opacity, lessThan(1.0));

      await settleUnfold(tester);
      expect(
        tester.widget<Opacity>(find.byKey(revealUnfoldOpacityKey)).opacity,
        1.0,
      );
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      expect(find.text('Partner reply here.'), findsOneWidget);
    });

    testWidgets('the live waiting→revealed transition fires ONE gentle '
        'lightImpact haptic — AT beat 2\'s settle, not on the slot flip', (
      tester,
    ) async {
      final haptics = spyHaptics(tester);
      final fakes = await pumpPaired(tester, initialAnswers: ownOnly());
      await tester.pumpAndSettle();
      expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
      expect(haptics, isEmpty); // nothing before the reveal

      fakes.answers.emitAnswer(
        coupleId,
        todayKey,
        partnerUid,
        ackedAnswer('Partner reply here.'),
      );
      await pumpUntil(tester, find.text(en.pairedRevealedCaption));
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      // The choreography has mounted but the pair has not settled: the haptic
      // belongs to beat 2 (ui-ux §11 — "the light haptic fires at the settle"),
      // so nothing has buzzed yet.
      expect(haptics, isEmpty);

      await pumpPastSettle(tester);
      expect(haptics, hasLength(1));
      expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
      await settleUnfold(tester);
      expect(haptics, hasLength(1)); // beat 3 adds nothing
    });

    testWidgets(
      'cold-open into revealed fires exactly ONE haptic as the reveal '
      'settles in (the read chain still passes waiting→revealed)',
      (tester) async {
        // Honest bound: the slot settles Locked→Waiting→Revealed even when both
        // answers already exist, so cold-open replays the choreography and buzzes
        // once at its settle — there is no cheap client signal separating it from
        // the live moment. It is bounded to ONCE per instance (see the next
        // test), and app-resume never re-fires.
        final haptics = spyHaptics(tester);
        await pumpPaired(tester, initialAnswers: bothAnswered());
        await pumpUntil(tester, find.text(en.pairedRevealedCaption));

        expect(find.text(en.pairedRevealedCaption), findsOneWidget);
        expect(find.text('Partner reply here.'), findsOneWidget);
        expect(haptics, isEmpty); // not yet — the settle carries the buzz

        await pumpPastSettle(tester);
        expect(haptics, hasLength(1));
        expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
        await settleUnfold(tester);
        expect(haptics, hasLength(1));
      },
    );

    testWidgets('the reveal haptic is at-most-once per instance: the '
        'permission-denial self-heal (locked→revealed) adds NONE', (
      tester,
    ) async {
      final haptics = spyHaptics(tester);
      final fakes = await pumpPaired(tester, initialAnswers: bothAnswered());
      await pumpUntil(tester, find.text(en.pairedRevealedCaption));
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      await settleUnfold(tester);
      expect(haptics, hasLength(1)); // the cold-open settle fired once

      // A lost exists()-race denies the partner listen → the slot maps back to
      // Locked (defense-in-depth), then the bounded 1s retry replays the stored
      // answer and re-reveals. The choreography REMOUNTS and replays its beats
      // (motion is per-mount), but the once-per-instance haptic flag is already
      // set, so its onSettle is swallowed.
      fakes.answers.emitError(
        coupleId,
        todayKey,
        partnerUid,
        const CoupleDataPermissionException(message: 'denied'),
      );
      await pumpUntil(tester, find.text(en.pairedPartnerLocked));
      expect(find.text(en.pairedPartnerLocked), findsOneWidget);

      await tester.pump(const Duration(seconds: 1)); // fire the bounded retry
      await pumpUntil(tester, find.text(en.pairedPartnerAnswerLabel));
      expect(find.text(en.pairedPartnerAnswerLabel), findsOneWidget);
      await settleUnfold(tester); // replay the beats past their settle
      // Still exactly one — the self-heal added no buzz.
      expect(haptics, hasLength(1));
    });

    testWidgets('reduce-motion collapses the choreography to an instant '
        'crossfade (opacity 1 on the first revealed frame) with the haptic '
        'PRESERVED', (tester) async {
      final haptics = spyHaptics(tester);
      final fakes = await pumpPaired(
        tester,
        reduceMotion: true,
        initialAnswers: ownOnly(),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
      expect(haptics, isEmpty);

      fakes.answers.emitAnswer(
        coupleId,
        todayKey,
        partnerUid,
        ackedAnswer('Partner reply here.'),
      );
      await pumpUntil(tester, find.byKey(revealUnfoldOpacityKey));
      expect(find.text(en.pairedRevealedCaption), findsOneWidget);
      // Collapsed → the group is already fully in place on frame one, no fade
      // — and nothing left ticking, so no settle needed.
      expect(
        tester.widget<Opacity>(find.byKey(revealUnfoldOpacityKey)).opacity,
        1.0,
      );
      // ui-ux §8: "the reveal must remain operable and feelable without
      // animation" — the settle hook still buzzed exactly once, instantly.
      expect(haptics, hasLength(1));
      expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    // ADR-051 / #174 — the HEARD half. Every case below mirrors a haptic case
    // above, because the two are one event on two channels and a divergence
    // between them is the defect the single guard exists to prevent.
    group('the reveal ANNOUNCES, exactly once (ADR-051, #174)', () {
      testWidgets('a live reveal announces once at the settle, and a rebuild '
          'does not repeat it', (tester) async {
        final announcements = spyAnnouncements(tester);
        final fakes = await pumpPaired(tester, initialAnswers: ownOnly());
        await tester.pumpAndSettle();
        expect(announcements, isEmpty);

        fakes.answers.emitAnswer(
          coupleId,
          todayKey,
          partnerUid,
          ackedAnswer('Partner reply here.'),
        );
        await pumpUntil(tester, find.text(en.pairedRevealedCaption));
        // Beat 2 carries it, exactly as it carries the haptic — not the mount.
        expect(announcements, isEmpty);

        await pumpPastSettle(tester);
        expect(announcements, hasLength(1));
        expect(announcements.single['message'], en.pairedRevealAnnouncement);

        // THE ASSERTION #174 ASKS FOR IN ITS OWN WORDS: not that a node exists,
        // but that a rebuild does not speak again. An announcement that repeats
        // interrupts the listener mid-sentence — worse than silence.
        await settleUnfold(tester);
        await tester.pump();
        expect(announcements, hasLength(1));
      });

      testWidgets('reduce-motion keeps the announcement, as it keeps the '
          'haptic', (tester) async {
        // The user who turned motion off is disproportionately likely to be the
        // one listening, so this is the case that matters most.
        final announcements = spyAnnouncements(tester);
        final fakes = await pumpPaired(
          tester,
          reduceMotion: true,
          initialAnswers: ownOnly(),
        );
        await tester.pumpAndSettle();
        expect(announcements, isEmpty);

        fakes.answers.emitAnswer(
          coupleId,
          todayKey,
          partnerUid,
          ackedAnswer('Partner reply here.'),
        );
        await pumpUntil(tester, find.text(en.pairedRevealedCaption));
        expect(announcements, hasLength(1));
        expect(announcements.single['message'], en.pairedRevealAnnouncement);
      });

      // locked and waiting both mount a partner card. If the announcement rode a
      // MOUNT rather than the settle, they would speak — which is exactly why
      // ADR-051 D1 rejects the card's own mount as the fire point. One test per
      // state: a second pumpPaired in the same test rebuilds over the first
      // tree rather than replacing it, and the assertion would then be about a
      // screen that is not the one named.
      testWidgets('the LOCKED state stays silent', (tester) async {
        final announcements = spyAnnouncements(tester);
        await pumpPaired(tester);
        await tester.pumpAndSettle();
        expect(find.text(en.pairedPartnerLocked), findsOneWidget);
        expect(announcements, isEmpty);
      });

      testWidgets('the WAITING state stays silent', (tester) async {
        final announcements = spyAnnouncements(tester);
        await pumpPaired(tester, initialAnswers: ownOnly());
        await tester.pumpAndSettle();
        expect(find.text(en.pairedPartnerWaiting), findsOneWidget);
        expect(announcements, isEmpty);
      });

      testWidgets('the announcement carries the AMBIENT direction — LTR', (
        tester,
      ) async {
        final announcements = spyAnnouncements(tester);
        await pumpPaired(tester, initialAnswers: bothAnswered());
        await pumpUntil(tester, find.text(en.pairedRevealedCaption));
        await pumpPastSettle(tester);

        expect(announcements, hasLength(1));
        expect(announcements.single['textDirection'], TextDirection.ltr.index);
      });

      testWidgets('...and RTL in Arabic, with the Arabic string', (
        tester,
      ) async {
        // An announcement queued with the wrong direction is the one bidi
        // failure (ADR-033) no golden can catch, because it is never drawn.
        final announcements = spyAnnouncements(tester);
        await pumpPaired(
          tester,
          locale: const Locale('ar'),
          initialAnswers: bothAnswered(),
        );
        await pumpUntil(tester, find.text(ar.pairedRevealedCaption));
        await pumpPastSettle(tester);

        expect(announcements, hasLength(1));
        expect(announcements.single['message'], ar.pairedRevealAnnouncement);
        expect(announcements.single['textDirection'], TextDirection.rtl.index);
      });
    });
  });
}
