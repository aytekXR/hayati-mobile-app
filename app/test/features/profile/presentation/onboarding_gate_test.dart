import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_screen.dart';
import 'package:hayati_app/features/daily_question/presentation/solo_home_screen.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/presentation/partner_preview_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_exception.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/onboarding_gate.dart';
import 'package:hayati_app/features/profile/presentation/profile_capture_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_couple_answers_repository.dart';
import '../../../support/fake_couple_day_repository.dart';
import '../../../support/fake_couple_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_invite_preview_repository.dart';
import '../../../support/fake_invite_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/fake_question_pack_repository.dart';
import '../../../support/fake_solo_answers_repository.dart';
import '../../../support/fake_solo_question_pack_repository.dart';
import '../../../support/localized_app.dart';

const user = AuthUser(uid: 'uid-1', displayName: 'Aytek');
const existingProfile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
);
const pairedProfile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
  coupleId: 'couple-42',
);

void main() {
  Future<FakeProfileRepository> pumpGate(
    WidgetTester tester, {
    RelationshipProfile? profile,
    Uri? initialLink,
    Locale locale = const Locale('en'),
  }) async {
    final fake = FakeProfileRepository(initialProfiles: {user.uid: ?profile});
    final fakeAuth = FakeAuthRepository(initialUser: user);
    final fakeInvites = FakeInviteRepository();
    final fakePreviews = FakeInvitePreviewRepository();
    // The gate now watches pendingInviteProvider → deepLinkSourceProvider (which
    // throws unoverridden); an empty source (the default) keeps the pending
    // invite null so an onboarded-but-solo profile routes to the solo home
    // (M2.4). A non-null [initialLink] seeds a pending code for the
    // precedence tests.
    final fakeDeepLinks = FakeDeepLinkSource(initialUri: initialLink);
    // The solo-home fallback needs its pack + answers seams; day-N stays 1
    // because the const test profiles carry no createdAt.
    final fakePacks = FakeSoloQuestionPackRepository();
    final fakeAnswers = FakeSoloAnswersRepository();
    // The paired route (M3.3) needs the couple seams. The seeded couple-42
    // matches pairedProfile.coupleId; the unseeded day replays null, so the
    // paired home settles on the honest no-day-yet state — the gate tests
    // only assert routing.
    final fakeCouples = FakeCoupleRepository(
      initialCouples: {
        'couple-42': Couple(
          id: 'couple-42',
          memberUids: [user.uid, 'uid-partner'],
          timezone: 'Europe/Istanbul',
        ),
      },
    );
    final fakeDays = FakeCoupleDayRepository();
    final fakeCoupleAnswers = FakeCoupleAnswersRepository();
    final fakeCouplePacks = FakeQuestionPackRepository();
    addTearDown(fakeCouples.dispose);
    addTearDown(fakeDays.dispose);
    addTearDown(fakeCoupleAnswers.dispose);
    addTearDown(fake.dispose);
    addTearDown(fakeAuth.dispose);
    addTearDown(fakeInvites.dispose);
    addTearDown(fakePreviews.dispose);
    addTearDown(fakeDeepLinks.dispose);
    addTearDown(fakeAnswers.dispose);
    await tester.pumpWidget(
      localizedApp(
        const OnboardingGate(user: user),
        locale: locale,
        overrides: [
          profileRepositoryProvider.overrideWith((ref) => fake),
          authRepositoryProvider.overrideWith((ref) => fakeAuth),
          inviteRepositoryProvider.overrideWith((ref) => fakeInvites),
          invitePreviewRepositoryProvider.overrideWith((ref) => fakePreviews),
          deepLinkSourceProvider.overrideWith((ref) => fakeDeepLinks),
          soloQuestionPackRepositoryProvider.overrideWith((ref) => fakePacks),
          soloAnswersRepositoryProvider.overrideWith((ref) => fakeAnswers),
          coupleRepositoryProvider.overrideWith((ref) => fakeCouples),
          coupleDayRepositoryProvider.overrideWith((ref) => fakeDays),
          coupleAnswersRepositoryProvider.overrideWith(
            (ref) => fakeCoupleAnswers,
          ),
          questionPackRepositoryProvider.overrideWith(
            (ref) => fakeCouplePacks,
          ),
        ],
      ),
    );
    return fake;
  }

  group('loading state', () {
    testWidgets('shows a spinner until the profile stream emits', (
      tester,
    ) async {
      await pumpGate(tester);

      // async* streams need a microtask to emit; before that: loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('content states', () {
    testWidgets('fresh signup (no profile) routes to capture', (tester) async {
      await pumpGate(tester);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileCaptureScreen), findsOneWidget);
      expect(find.byType(SoloHomeScreen), findsNothing);
    });

    testWidgets('an existing solo profile with no pending invite routes to '
        'the solo home (M2.4)', (tester) async {
      await pumpGate(tester, profile: existingProfile);
      await tester.pumpAndSettle();

      expect(find.byType(SoloHomeScreen), findsOneWidget);
      expect(find.byType(ProfileCaptureScreen), findsNothing);
    });

    testWidgets('a solo profile WITH a pending invite routes to the partner '
        'preview (pending beats the share screen)', (tester) async {
      await pumpGate(
        tester,
        profile: existingProfile,
        initialLink: Uri.parse('hayati://invite/ABCD2345'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerPreviewScreen), findsOneWidget);
      expect(find.byType(SoloHomeScreen), findsNothing);
    });

    testWidgets('a paired profile routes to the paired home — coupleId beats '
        'even a pending invite', (tester) async {
      await pumpGate(
        tester,
        profile: pairedProfile,
        initialLink: Uri.parse('hayati://invite/ABCD2345'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PairedHomeScreen), findsOneWidget);
      expect(find.byType(PartnerPreviewScreen), findsNothing);
      expect(find.byType(SoloHomeScreen), findsNothing);
    });

    testWidgets('pairing completing on another device swaps the preview for '
        'the paired home live', (tester) async {
      final fake = await pumpGate(
        tester,
        profile: existingProfile,
        initialLink: Uri.parse('hayati://invite/ABCD2345'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PartnerPreviewScreen), findsOneWidget);

      fake.emitProfile(user.uid, pairedProfile);
      await tester.pumpAndSettle();

      expect(find.byType(PairedHomeScreen), findsOneWidget);
    });

    testWidgets('a profile arriving from another device swaps to the '
        'solo home live', (tester) async {
      final fake = await pumpGate(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileCaptureScreen), findsOneWidget);

      fake.emitProfile(user.uid, existingProfile);
      await tester.pumpAndSettle();

      expect(find.byType(SoloHomeScreen), findsOneWidget);
    });

    testWidgets('pairing mid-solo (coupleId arriving on the live stream) '
        're-routes the solo home to the paired home', (tester) async {
      final fake = await pumpGate(tester, profile: existingProfile);
      await tester.pumpAndSettle();
      expect(find.byType(SoloHomeScreen), findsOneWidget);

      fake.emitProfile(user.uid, pairedProfile);
      await tester.pumpAndSettle();

      expect(find.byType(PairedHomeScreen), findsOneWidget);
      expect(find.byType(SoloHomeScreen), findsNothing);
    });
  });

  group('error state', () {
    testWidgets('a stream failure shows the retry affordance and retrying '
        'resubscribes', (tester) async {
      final fake = await pumpGate(tester);
      await tester.pumpAndSettle();
      fake.emitError(user.uid, const ProfileNetworkException(message: 'off'));
      await tester.pumpAndSettle();

      final en = l10nFor(const Locale('en'));
      expect(find.text(en.errorNetworkRetry), findsOneWidget);
      expect(find.text(en.tryAgain), findsOneWidget);

      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileCaptureScreen), findsOneWidget);
    });
  });

  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets('renders loading→capture→solo home localized ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        final fake = await pumpGate(tester, locale: locale);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text(l10n.onboardingTitle), findsOneWidget);

        fake.emitProfile(user.uid, existingProfile);
        await tester.pumpAndSettle();

        // Day 1 (no createdAt on the test profile) with the persistent nudge;
        // UI chrome follows the UI locale while the question itself renders
        // in the profile's content language (tr for existingProfile).
        expect(find.text(l10n.soloDayProgress(1)), findsOneWidget);
        expect(find.text(l10n.soloNudgeAction), findsOneWidget);
        expect(find.text('TR solo question 1'), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(OnboardingGate))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
