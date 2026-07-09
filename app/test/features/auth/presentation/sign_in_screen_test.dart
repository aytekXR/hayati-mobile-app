import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/phone_sign_in_screen.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/presentation/invite_share_screen.dart';
import 'package:hayati_app/features/pairing/presentation/partner_preview_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/profile_capture_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_invite_preview_repository.dart';
import '../../../support/fake_invite_repository.dart';
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
    Uri? initialLink,
    Locale locale = const Locale('en'),
  }) async {
    final fake = FakeAuthRepository(initialUser: initialUser);
    final fakeProfiles = FakeProfileRepository(
      initialProfiles: {testUser.uid: ?profile},
    );
    final fakeInvites = FakeInviteRepository();
    final fakePreviews = FakeInvitePreviewRepository();
    // No pending deep-link code by default (the not-signed-in branch now watches
    // pendingInviteProvider → deepLinkSourceProvider, which throws unoverridden):
    // an empty source keeps the pending invite null so these tests see the plain
    // auth shell. A non-null [initialLink] seeds a pending code so the pre-auth
    // partner-preview branch renders instead.
    final fakeDeepLinks = FakeDeepLinkSource(initialUri: initialLink);
    addTearDown(fake.dispose);
    addTearDown(fakeProfiles.dispose);
    addTearDown(fakeInvites.dispose);
    addTearDown(fakePreviews.dispose);
    addTearDown(fakeDeepLinks.dispose);
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
          inviteRepositoryProvider.overrideWith((ref) => fakeInvites),
          invitePreviewRepositoryProvider.overrideWith((ref) => fakePreviews),
          deepLinkSourceProvider.overrideWith((ref) => fakeDeepLinks),
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

    testWidgets('offers Apple, Google and phone affordances', (tester) async {
      await pumpScreen(tester);

      expect(find.text(en.continueWithApple), findsOneWidget);
      expect(find.text(en.continueWithGoogle), findsOneWidget);
      expect(find.text(en.continueWithPhone), findsOneWidget);
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

    testWidgets('tapping Apple starts the Apple flow', (tester) async {
      final fake = await pumpScreen(tester);
      final completer = Completer<AuthUser>();
      fake.onSignInWithApple = () => completer.future;

      await tester.tap(find.text(en.continueWithApple));
      await tester.pump();

      expect(fake.signInWithAppleCalls, 1);

      completer.complete(testUser);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping phone opens the phone sign-in screen', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text(en.continueWithPhone));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneSignInScreen), findsOneWidget);
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
      expect(find.text(en.continueWithGoogle), findsOneWidget);

      fake.onSignInWithGoogle = () async => testUser;
      await tester.tap(find.text(en.continueWithGoogle));
      await tester.pumpAndSettle();

      expect(fake.signInCalls, 2);
      // Successful sign-in hands the screen to onboarding (fresh signup).
      expect(find.byType(ProfileCaptureScreen), findsOneWidget);
    });

    testWidgets('the error view retries the provider that failed, not a '
        'hardcoded one', (tester) async {
      final fake = await pumpScreen(tester);
      fake.onSignInWithApple = () async {
        throw const AuthNetworkException(message: 'offline');
      };

      await tester.tap(find.text(en.continueWithApple));
      await tester.pumpAndSettle();
      expect(find.text(en.signInFailedTitle), findsOneWidget);

      // Retrying from the error view must re-run Apple; a single "try again"
      // bound to Google would silently start the wrong flow.
      fake.onSignInWithApple = () async => testUser;
      await tester.tap(find.text(en.continueWithApple));
      await tester.pumpAndSettle();

      expect(fake.signInWithAppleCalls, 2);
      expect(fake.signInCalls, 0);
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

  group('pre-auth partner preview', () {
    testWidgets('a pending invite shows the preview BEFORE sign-in (the '
        'activation moment)', (tester) async {
      await pumpScreen(
        tester,
        initialLink: Uri.parse('hayati://invite/ABCD2345'),
      );
      await tester.pumpAndSettle();

      // Who invited them, then the sign-in choice — not the plain auth shell.
      expect(find.byType(PartnerPreviewScreen), findsOneWidget);
      expect(find.text(en.invitePreviewInvitedBy('Aylin')), findsOneWidget);
      expect(find.text(en.continueWithApple), findsOneWidget);
    });

    testWidgets('no pending invite keeps the plain auth shell', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(PartnerPreviewScreen), findsNothing);
      expect(find.text(kBrandName), findsOneWidget);
    });
  });

  group('signed-in routing', () {
    testWidgets('a fresh signup lands on profile capture', (tester) async {
      await pumpScreen(tester, initialUser: testUser);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileCaptureScreen), findsOneWidget);
      expect(find.text(en.onboardingTitle), findsOneWidget);
    });

    testWidgets('an existing profile lands on the invite share screen and '
        'can sign out', (tester) async {
      final fake = await pumpScreen(
        tester,
        initialUser: testUser,
        profile: testProfile,
      );
      await tester.pumpAndSettle();

      expect(find.byType(InviteShareScreen), findsOneWidget);
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
        // The error view re-offers every provider (localized), so the user can
        // retry the one that failed rather than a hardcoded default.
        expect(find.text(l10n.continueWithApple), findsOneWidget);
        expect(find.text(l10n.continueWithGoogle), findsOneWidget);
        expect(find.text(l10n.continueWithPhone), findsOneWidget);
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
