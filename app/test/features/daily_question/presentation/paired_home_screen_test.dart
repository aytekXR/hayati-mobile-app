import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

import '../../../support/fake_couple_answers_repository.dart';
import '../../../support/fake_couple_day_repository.dart';
import '../../../support/fake_couple_repository.dart';
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

void main() {
  final en = l10nFor(const Locale('en'));

  Future<
    ({
      FakeCoupleRepository couples,
      FakeCoupleDayRepository days,
      FakeCoupleAnswersRepository answers,
      FakeQuestionPackRepository packs,
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
    addTearDown(couples.dispose);
    addTearDown(days.dispose);
    addTearDown(answers.dispose);
    // The clock seam: a mutable holder (`clock`) drives the app-resume re-key;
    // everything else pins a fixed instant.
    final clockFn = clock ?? (() => now ?? fixedNow);
    await tester.pumpWidget(
      localizedApp(
        const PairedHomeScreen(uid: ownUid, coupleId: coupleId),
        locale: locale,
        overrides: [
          coupleRepositoryProvider.overrideWith((ref) => couples),
          coupleDayRepositoryProvider.overrideWith((ref) => days),
          coupleAnswersRepositoryProvider.overrideWith((ref) => answers),
          questionPackRepositoryProvider.overrideWith((ref) => packs),
          soloClockProvider.overrideWith((ref) => clockFn),
        ],
      ),
    );
    return (couples: couples, days: days, answers: answers, packs: packs);
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
      expect(find.text('EN paired question 1'), findsNothing);

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
      expect(find.text('EN paired question 1'), findsNothing);
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
}
