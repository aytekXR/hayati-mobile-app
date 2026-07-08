import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/profile/domain/profile_exception.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/invite_partner_placeholder.dart';
import 'package:hayati_app/features/profile/presentation/onboarding_gate.dart';
import 'package:hayati_app/features/profile/presentation/profile_capture_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/localized_app.dart';

const user = AuthUser(uid: 'uid-1', displayName: 'Aytek');
const existingProfile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
);

void main() {
  Future<FakeProfileRepository> pumpGate(
    WidgetTester tester, {
    RelationshipProfile? profile,
    Locale locale = const Locale('en'),
  }) async {
    final fake = FakeProfileRepository(initialProfiles: {user.uid: ?profile});
    final fakeAuth = FakeAuthRepository(initialUser: user);
    addTearDown(fake.dispose);
    addTearDown(fakeAuth.dispose);
    await tester.pumpWidget(
      localizedApp(
        const OnboardingGate(user: user),
        locale: locale,
        overrides: [
          profileRepositoryProvider.overrideWith((ref) => fake),
          authRepositoryProvider.overrideWith((ref) => fakeAuth),
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
      expect(find.byType(InvitePartnerPlaceholder), findsNothing);
    });

    testWidgets('an existing profile routes to the invite placeholder', (
      tester,
    ) async {
      await pumpGate(tester, profile: existingProfile);
      await tester.pumpAndSettle();

      expect(find.byType(InvitePartnerPlaceholder), findsOneWidget);
      expect(find.byType(ProfileCaptureScreen), findsNothing);
    });

    testWidgets('a profile arriving from another device swaps to the '
        'placeholder live', (tester) async {
      final fake = await pumpGate(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileCaptureScreen), findsOneWidget);

      fake.emitProfile(user.uid, existingProfile);
      await tester.pumpAndSettle();

      expect(find.byType(InvitePartnerPlaceholder), findsOneWidget);
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
      testWidgets('renders loading→capture→placeholder localized ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        final fake = await pumpGate(tester, locale: locale);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text(l10n.onboardingTitle), findsOneWidget);

        fake.emitProfile(user.uid, existingProfile);
        await tester.pumpAndSettle();

        expect(find.text(l10n.invitePartnerTitle), findsOneWidget);
        expect(find.text(l10n.invitePartnerBody), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(OnboardingGate))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
