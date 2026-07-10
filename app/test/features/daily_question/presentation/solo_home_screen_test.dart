import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer_exception.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/daily_question/domain/solo_day.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/solo_home_screen.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';
import 'package:hayati_app/features/pairing/presentation/invite_share_screen.dart';
import 'package:hayati_app/features/pairing/presentation/partner_preview_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_invite_preview_repository.dart';
import '../../../support/fake_invite_repository.dart';
import '../../../support/fake_invite_share_launcher.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/fake_solo_answers_repository.dart';
import '../../../support/fake_solo_question_pack_repository.dart';
import '../../../support/localized_app.dart';

const user = AuthUser(uid: 'uid-1', displayName: 'Aytek');

/// The pinned wall clock: every test is clock-independent (the day-N proofs
/// must not depend on when the suite runs).
final fixedNow = DateTime(2026, 7, 10, 12);
final todayKey = soloDayKey(fixedNow); // 20260710

RelationshipProfile profileWith({
  DateTime? createdAt,
  ContentLanguage language = ContentLanguage.en,
  String? coupleId,
}) => RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: language,
  register: ContentRegister.respectful,
  coupleId: coupleId,
  createdAt: createdAt,
);

void main() {
  final en = l10nFor(const Locale('en'));

  Future<
    ({
      FakeSoloAnswersRepository answers,
      FakeSoloQuestionPackRepository packs,
      FakeProfileRepository profiles,
      FakeAuthRepository auth,
    })
  >
  pumpSolo(
    WidgetTester tester, {
    required RelationshipProfile profile,
    DateTime? now,
    Map<String, SoloAnswer>? initialAnswers,
    Locale locale = const Locale('en'),
    Future<void> Function(
      String uid,
      String dayKey,
      String questionId,
      String text,
    )?
    onSaveAnswer,
    Future<QuestionPack> Function(ContentLanguage language)? onLoadPack,
  }) async {
    final packs = FakeSoloQuestionPackRepository()..onLoadPack = onLoadPack;
    final answers = FakeSoloAnswersRepository(initialAnswers: initialAnswers)
      ..onSaveAnswer = onSaveAnswer;
    final profiles = FakeProfileRepository(
      initialProfiles: {user.uid: profile},
    );
    final auth = FakeAuthRepository(initialUser: user);
    final invites = FakeInviteRepository();
    final launcher = FakeInviteShareLauncher();
    // The share screen's "Have a code?" pushes the partner preview, which
    // watches pendingInviteProvider → deepLinkSourceProvider (throws
    // unoverridden) and the preview repository.
    final deepLinks = FakeDeepLinkSource();
    final previews = FakeInvitePreviewRepository();
    addTearDown(answers.dispose);
    addTearDown(profiles.dispose);
    addTearDown(auth.dispose);
    addTearDown(invites.dispose);
    addTearDown(launcher.dispose);
    addTearDown(deepLinks.dispose);
    addTearDown(previews.dispose);
    await tester.pumpWidget(
      localizedApp(
        SoloHomeScreen(uid: user.uid, profile: profile),
        locale: locale,
        overrides: [
          soloQuestionPackRepositoryProvider.overrideWith((ref) => packs),
          soloAnswersRepositoryProvider.overrideWith((ref) => answers),
          soloClockProvider.overrideWith(
            (ref) =>
                () => now ?? fixedNow,
          ),
          // The nudge pushes the share flow; its pop-on-pair/pop-on-signout
          // listeners and the share screen itself need these seams.
          profileRepositoryProvider.overrideWith((ref) => profiles),
          authRepositoryProvider.overrideWith((ref) => auth),
          inviteRepositoryProvider.overrideWith((ref) => invites),
          inviteShareLauncherProvider.overrideWith((ref) => launcher),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
          invitePreviewRepositoryProvider.overrideWith((ref) => previews),
        ],
      ),
    );
    return (answers: answers, packs: packs, profiles: profiles, auth: auth);
  }

  group('day-N rotation', () {
    testWidgets('a fresh user sees day 1 with its question and the nudge', (
      tester,
    ) async {
      await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.soloDayProgress(1)), findsOneWidget);
      expect(find.text('EN solo question 1'), findsOneWidget);
      expect(find.text(en.soloNudgeBody), findsOneWidget);
      expect(find.text(en.soloNudgeAction), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('day 3 on the third calendar date even when <48h elapsed '
        '(clock-independent acceptance proof)', (tester) async {
      await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 8, 10)),
        now: DateTime(2026, 7, 10, 9), // 47h after the anchor
      );
      await tester.pumpAndSettle();

      expect(find.text(en.soloDayProgress(3)), findsOneWidget);
      expect(find.text('EN solo question 3'), findsOneWidget);
    });

    testWidgets('a null createdAt (pending server stamp) is day 1', (
      tester,
    ) async {
      await pumpSolo(tester, profile: profileWith());
      await tester.pumpAndSettle();

      expect(find.text(en.soloDayProgress(1)), findsOneWidget);
    });

    testWidgets('the question renders in the profile content language, not '
        'the UI locale', (tester) async {
      await pumpSolo(
        tester,
        profile: profileWith(language: ContentLanguage.tr),
      );
      await tester.pumpAndSettle();

      expect(find.text('TR solo question 1'), findsOneWidget);
      expect(find.text(en.soloNudgeAction), findsOneWidget); // chrome stays EN
    });
  });

  group('answer entry', () {
    testWidgets('saving persists through the repository and shows the saved '
        'caption', (tester) async {
      final fakes = await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 8)),
      );
      await tester.pumpAndSettle();

      // Empty entry → nothing to save.
      final saveButton = find.widgetWithText(FilledButton, en.soloAnswerSave);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

      await tester.enterText(
        find.byType(TextField),
        'A quiet morning together.  ',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(fakes.answers.saveCalls, 1);
      // Trimmed, and bound to the day's question (day 3 here).
      expect(fakes.answers.savedTexts, ['A quiet morning together.']);
      expect(fakes.answers.savedQuestionIds, ['solo_en_003']);
      expect(find.text(en.soloAnswerSavedCaption), findsOneWidget);
      // Nothing new to save until the entry changes again.
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets('a persisted answer survives a restart: the field is '
        'prefilled and marked saved', (tester) async {
      // A fresh pump with a seeded repository IS the restart: state lives in
      // the store (Firestore in production), not the widget.
      await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
        initialAnswers: {
          FakeSoloAnswersRepository.keyFor(user.uid, todayKey): SoloAnswer(
            questionId: 'solo_en_001',
            text: 'Persisted from before the restart.',
            answeredAt: FakeSoloAnswersRepository.answeredAtStamp,
          ),
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Persisted from before the restart.'), findsOneWidget);
      expect(find.text(en.soloAnswerSavedCaption), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, en.soloAnswerSave);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets('editing a saved answer re-enables save and updates it', (
      tester,
    ) async {
      final fakes = await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
        initialAnswers: {
          FakeSoloAnswersRepository.keyFor(user.uid, todayKey): SoloAnswer(
            questionId: 'solo_en_001',
            text: 'First thought.',
            answeredAt: FakeSoloAnswersRepository.answeredAtStamp,
          ),
        },
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Second thought.');
      await tester.pump();
      expect(find.text(en.soloAnswerSavedCaption), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, en.soloAnswerSave));
      await tester.pumpAndSettle();

      expect(fakes.answers.savedTexts, ['Second thought.']);
      expect(find.text(en.soloAnswerSavedCaption), findsOneWidget);
    });

    testWidgets('the entry field hard-caps at the rules ceiling, so an '
        'over-length save is unrepresentable (review finding, Session 010)', (
      tester,
    ) async {
      await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'x' * (soloAnswerMaxLength + 1),
      );
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, soloAnswerMaxLength);
    });

    testWidgets('a save failure surfaces honest inline copy and keeps the '
        'entry editable', (tester) async {
      await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
        onSaveAnswer: (uid, dayKey, questionId, text) async {
          throw const SoloAnswerNetworkException(message: 'off');
        },
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Will fail.');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, en.soloAnswerSave));
      await tester.pumpAndSettle();

      expect(find.text(en.errorNetworkRetry), findsOneWidget);
      final saveButton = find.widgetWithText(FilledButton, en.soloAnswerSave);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });
  });

  group('completed state (day 8+)', () {
    testWidgets('the cycle stops after day 7 and the nudge becomes the '
        'primary action', (tester) async {
      await pumpSolo(
        tester,
        // Anchor 7 calendar days back → day 8.
        profile: profileWith(createdAt: DateTime(2026, 7, 3, 18)),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.soloCompletedTitle), findsOneWidget);
      expect(find.text(en.soloCompletedBody), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, en.soloNudgeAction),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      // No question leaks past the cycle.
      expect(find.textContaining('solo question'), findsNothing);
    });

    testWidgets('the completed state routes to the share flow', (tester) async {
      await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 1)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, en.soloNudgeAction));
      await tester.pumpAndSettle();

      expect(find.byType(InviteShareScreen), findsOneWidget);
    });
  });

  group('invite nudge routing', () {
    testWidgets('the nudge pushes the invite share screen', (tester) async {
      await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.soloNudgeAction));
      await tester.pumpAndSettle();

      expect(find.byType(InviteShareScreen), findsOneWidget);
      expect(find.text(en.invitePartnerTitle), findsOneWidget);
    });

    testWidgets('the pushed share screen pops itself when the partner joins '
        '(coupleId arrives on the live stream)', (tester) async {
      final fakes = await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.soloNudgeAction));
      await tester.pumpAndSettle();
      expect(find.byType(InviteShareScreen), findsOneWidget);

      fakes.profiles.emitProfile(
        user.uid,
        profileWith(createdAt: DateTime(2026, 7, 10, 9), coupleId: 'couple-42'),
      );
      await tester.pumpAndSettle();

      // Popped: in production the gate underneath has already re-routed to
      // the paired home (proven at the gate level); here the home resurfaces.
      expect(find.byType(InviteShareScreen), findsNothing);
      expect(find.byType(SoloHomeScreen), findsOneWidget);
    });

    testWidgets('pairing collapses the WHOLE pushed stack — even a partner '
        'preview stacked via "Have a code?" (review finding, Session 010)', (
      tester,
    ) async {
      final fakes = await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.soloNudgeAction));
      await tester.pumpAndSettle();
      // The inviter drills into the invitee-side entry on top of the pushed
      // share screen: gate → share → partner preview.
      await tester.tap(find.text(en.joinHaveCodeAction));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerPreviewScreen), findsOneWidget);

      // Partner redeems the invite meanwhile: a bare pop() here would remove
      // only the preview and strand the paired user on the stale share
      // screen; popUntil must land back on the (re-routed) gate.
      fakes.profiles.emitProfile(
        user.uid,
        profileWith(createdAt: DateTime(2026, 7, 10, 9), coupleId: 'couple-42'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerPreviewScreen), findsNothing);
      expect(find.byType(InviteShareScreen), findsNothing);
      expect(find.byType(SoloHomeScreen), findsOneWidget);
    });

    testWidgets('signing out from the pushed share screen pops it, so the '
        'auth shell underneath is uncovered', (tester) async {
      final fakes = await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.soloNudgeAction));
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.signOut));
      await tester.pumpAndSettle();

      expect(fakes.auth.signOutCalls, 1);
      expect(find.byType(InviteShareScreen), findsNothing);
    });
  });

  group('error states', () {
    testWidgets('an answer-stream failure shows honest retryable copy WITH '
        'the nudge, and retry resubscribes', (tester) async {
      final fakes = await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
      );
      await tester.pumpAndSettle();

      fakes.answers.emitError(
        user.uid,
        todayKey,
        const SoloAnswerNetworkException(message: 'off'),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.errorNetworkRetry), findsOneWidget);
      expect(find.text(en.soloNudgeAction), findsOneWidget); // nudge persists
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();

      expect(find.text('EN solo question 1'), findsOneWidget);
    });

    testWidgets('a pack load failure shows the generic copy WITH the nudge, '
        'and retry reloads', (tester) async {
      final fakes = await pumpSolo(
        tester,
        profile: profileWith(createdAt: DateTime(2026, 7, 10, 9)),
        onLoadPack: (language) async {
          throw const FormatException('broken asset');
        },
      );
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
      expect(find.text(en.soloNudgeAction), findsOneWidget); // nudge persists
      expect(find.byType(TextField), findsNothing);

      fakes.packs.onLoadPack = null;
      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();

      expect(find.text('EN solo question 1'), findsOneWidget);
    });
  });

  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets('renders localized solo chrome ($locale)', (tester) async {
        final l10n = l10nFor(locale);
        final language = ContentLanguage.values.byName(locale.languageCode);
        await pumpSolo(
          tester,
          profile: profileWith(
            createdAt: DateTime(2026, 7, 10, 9),
            language: language,
          ),
          locale: locale,
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.soloDayProgress(1)), findsOneWidget);
        expect(find.text(l10n.soloNudgeBody), findsOneWidget);
        expect(find.text(l10n.soloNudgeAction), findsOneWidget);
        expect(
          find.text('${language.name.toUpperCase()} solo question 1'),
          findsOneWidget,
        );
        expect(
          Directionality.of(tester.element(find.byType(SoloHomeScreen))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
