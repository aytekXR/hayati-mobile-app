import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/invite_partner_placeholder.dart';
import 'package:hayati_app/features/profile/presentation/profile_capture_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/localized_app.dart';

const testUser = AuthUser(uid: 'uid-1', displayName: 'Aytek');
const testProfile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
);

void main() {
  Future<FakeAuthRepository> pumpScreen(
    WidgetTester tester, {
    AuthUser? initialUser,
    RelationshipProfile? profile,
    Locale locale = const Locale('en'),
  }) async {
    final fake = FakeAuthRepository(initialUser: initialUser);
    final fakeProfiles = FakeProfileRepository(
      initialProfiles: {testUser.uid: ?profile},
    );
    addTearDown(fake.dispose);
    addTearDown(fakeProfiles.dispose);
    await tester.pumpWidget(
      localizedApp(
        const SignInScreen(),
        locale: locale,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: AppFlavor.dev),
          ),
          authRepositoryProvider.overrideWith((ref) => fake),
          profileRepositoryProvider.overrideWith((ref) => fakeProfiles),
        ],
      ),
    );
    return fake;
  }

  final en = l10nFor(const Locale('en'));

  group('signed-out content state', () {
    testWidgets('shows the brand title and the Google button', (tester) async {
      await pumpScreen(tester);

      expect(find.text(kBrandName), findsOneWidget);
      expect(find.text(en.continueWithGoogle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tapping the button starts the Google flow', (tester) async {
      final fake = await pumpScreen(tester);
      final completer = Completer<AuthUser>();
      fake.onSignInWithGoogle = () => completer.future;

      await tester.tap(find.text(en.continueWithGoogle));
      await tester.pump();

      expect(fake.signInCalls, 1);

      completer.complete(testUser);
      await tester.pumpAndSettle();
    });
  });

  group('loading state', () {
    testWidgets('shows a progress indicator while signing in', (tester) async {
      final fake = await pumpScreen(tester);
      final completer = Completer<AuthUser>();
      fake.onSignInWithGoogle = () => completer.future;

      await tester.tap(find.text(en.continueWithGoogle));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(en.continueWithGoogle), findsNothing);

      completer.complete(testUser);
      await tester.pumpAndSettle();
    });
  });

  group('error state', () {
    testWidgets('shows the failure and retries on tap', (tester) async {
      final fake = await pumpScreen(tester);
      fake.onSignInWithGoogle = () async {
        throw const AuthNetworkException(message: 'offline');
      };

      await tester.tap(find.text(en.continueWithGoogle));
      await tester.pumpAndSettle();

      expect(find.text(en.signInFailedTitle), findsOneWidget);
      expect(find.text(en.tryAgain), findsOneWidget);

      fake.onSignInWithGoogle = () async => testUser;
      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();

      expect(fake.signInCalls, 2);
      // Successful sign-in hands the screen to onboarding (fresh signup).
      expect(find.byType(ProfileCaptureScreen), findsOneWidget);
    });

    testWidgets('network failures get retry-specific copy', (tester) async {
      final fake = await pumpScreen(tester);
      fake.onSignInWithGoogle = () async {
        throw const AuthNetworkException(message: 'offline');
      };

      await tester.tap(find.text(en.continueWithGoogle));
      await tester.pumpAndSettle();

      expect(find.text(en.errorNetworkRetry), findsOneWidget);
    });

    testWidgets('unknown failures get generic copy', (tester) async {
      final fake = await pumpScreen(tester);
      fake.onSignInWithGoogle = () async {
        throw const AuthUnknownException(code: 'internal-error');
      };

      await tester.tap(find.text(en.continueWithGoogle));
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
    });
  });

  group('signed-in routing', () {
    testWidgets('a fresh signup lands on profile capture', (tester) async {
      await pumpScreen(tester, initialUser: testUser);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileCaptureScreen), findsOneWidget);
      expect(find.text(en.onboardingTitle), findsOneWidget);
    });

    testWidgets('an existing profile lands on the invite placeholder and '
        'can sign out', (tester) async {
      final fake = await pumpScreen(
        tester,
        initialUser: testUser,
        profile: testProfile,
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvitePartnerPlaceholder), findsOneWidget);
      expect(find.text(en.signOut), findsOneWidget);

      await tester.tap(find.text(en.signOut));
      await tester.pumpAndSettle();

      expect(fake.signOutCalls, 1);
      expect(find.text(en.continueWithGoogle), findsOneWidget);
    });
  });

  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets('renders localized copy through the states ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        final fake = await pumpScreen(tester, locale: locale);

        expect(find.text(l10n.continueWithGoogle), findsOneWidget);
        // RTL must derive from the locale alone (no manual Directionality).
        final direction = Directionality.of(
          tester.element(find.byType(SignInScreen)),
        );
        expect(
          direction,
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );

        fake.onSignInWithGoogle = () async {
          throw const AuthUnknownException(code: 'internal-error');
        };
        await tester.tap(find.text(l10n.continueWithGoogle));
        await tester.pumpAndSettle();

        expect(find.text(l10n.signInFailedTitle), findsOneWidget);
        expect(find.text(l10n.errorGeneric), findsOneWidget);
        expect(find.text(l10n.tryAgain), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('locale resolution', () {
    testWidgets('unsupported device locales resolve to English', (
      tester,
    ) async {
      await pumpScreen(tester, locale: const Locale('de'));

      expect(find.text(en.continueWithGoogle), findsOneWidget);
    });
  });
}
