import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';
import 'package:hayati_app/features/auth/presentation/phone_sign_in_screen.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/presentation/profile_capture_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/localized_app.dart';

const testUser = AuthUser(uid: 'uid-1', displayName: 'Aytek');
const session = PhoneSignInSession('vid-1', resendToken: 5);

void main() {
  final en = l10nFor(const Locale('en'));

  // Pumps the phone screen as the root route (no SignInScreen below), so
  // continueWithPhone renders only in the AppBar and state→widget assertions
  // stay unambiguous.
  Future<FakeAuthRepository> pumpPhoneScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      localizedApp(
        const PhoneSignInScreen(),
        locale: locale,
        overrides: [authRepositoryProvider.overrideWith((ref) => fake)],
      ),
    );
    return fake;
  }

  // Reaches the SMS-code screen: number entry → sendCode → PhoneCodeSent.
  Future<void> reachCodeEntry(
    WidgetTester tester,
    FakeAuthRepository fake,
  ) async {
    fake.onSendPhoneCode = (_, {resendFrom}) async => session;
    await tester.enterText(find.byType(TextField), '+905551112233');
    await tester.tap(find.text(en.sendCode));
    await tester.pumpAndSettle();
  }

  group('phone number entry', () {
    testWidgets('starts on the number field with a send action', (
      tester,
    ) async {
      await pumpPhoneScreen(tester);

      expect(find.text(en.phoneNumberLabel), findsOneWidget);
      expect(find.text(en.sendCode), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a send in flight replaces the field with progress', (
      tester,
    ) async {
      final fake = await pumpPhoneScreen(tester);
      final completer = Completer<PhoneSignInSession>();
      fake.onSendPhoneCode = (_, {resendFrom}) => completer.future;

      await tester.enterText(find.byType(TextField), '+905551112233');
      await tester.tap(find.text(en.sendCode));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(en.phoneNumberLabel), findsNothing);

      completer.complete(session);
      await tester.pumpAndSettle();
      expect(find.text(en.smsCodeLabel), findsOneWidget);
    });

    testWidgets('a send failure stays on entry with generic copy', (
      tester,
    ) async {
      final fake = await pumpPhoneScreen(tester);
      fake.onSendPhoneCode = (_, {resendFrom}) async {
        throw const AuthUnknownException(code: 'invalid-phone-number');
      };

      await tester.enterText(find.byType(TextField), '+900');
      await tester.tap(find.text(en.sendCode));
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
      expect(find.text(en.phoneNumberLabel), findsOneWidget);
      expect(find.text(en.sendCode), findsOneWidget);
    });
  });

  group('sms code entry', () {
    testWidgets('a sent code shows the code field, verify and resend', (
      tester,
    ) async {
      final fake = await pumpPhoneScreen(tester);
      await reachCodeEntry(tester, fake);

      expect(fake.sendPhoneCodeCalls, 1);
      expect(find.text(en.smsCodeLabel), findsOneWidget);
      expect(find.text(en.verifyCode), findsOneWidget);
      expect(find.text(en.resendCode), findsOneWidget);
    });

    testWidgets('resending keeps the code screen and shows progress', (
      tester,
    ) async {
      final fake = await pumpPhoneScreen(tester);
      await reachCodeEntry(tester, fake);

      final completer = Completer<PhoneSignInSession>();
      fake.onSendPhoneCode = (_, {resendFrom}) => completer.future;
      await tester.tap(find.text(en.resendCode));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The code UI stays visible while the resend is in flight.
      expect(find.text(en.smsCodeLabel), findsOneWidget);

      completer.complete(const PhoneSignInSession('vid-2'));
      await tester.pumpAndSettle();
      expect(find.text(en.resendCode), findsOneWidget);
    });

    testWidgets('a confirm in flight replaces the screen with progress', (
      tester,
    ) async {
      final fake = await pumpPhoneScreen(tester);
      await reachCodeEntry(tester, fake);

      final completer = Completer<AuthUser>();
      fake.onConfirmPhoneCode = (_, _) => completer.future;
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text(en.verifyCode));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(en.smsCodeLabel), findsNothing);

      // Settle back onto the code screen via a retained-session failure so the
      // infinite progress animation does not stall pumpAndSettle.
      completer.completeError(const AuthInvalidCodeException());
      await tester.pumpAndSettle();
    });
  });

  group('error copy paths', () {
    testWidgets('a wrong code shows inline retry copy on the code screen', (
      tester,
    ) async {
      final fake = await pumpPhoneScreen(tester);
      await reachCodeEntry(tester, fake);
      fake.onConfirmPhoneCode = (_, _) async {
        throw const AuthInvalidCodeException();
      };

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text(en.verifyCode));
      await tester.pumpAndSettle();

      expect(find.text(en.errorInvalidCode), findsOneWidget);
      // Session retained: still on the code screen for an inline retry.
      expect(find.text(en.smsCodeLabel), findsOneWidget);
      expect(find.text(en.verifyCode), findsOneWidget);
    });

    testWidgets(
      'an expired session returns to number entry with restart copy',
      (tester) async {
        final fake = await pumpPhoneScreen(tester);
        await reachCodeEntry(tester, fake);
        fake.onConfirmPhoneCode = (_, _) async {
          throw const AuthSessionExpiredException();
        };

        await tester.enterText(find.byType(TextField), '123456');
        await tester.tap(find.text(en.verifyCode));
        await tester.pumpAndSettle();

        expect(find.text(en.errorSessionExpired), findsOneWidget);
        // Session discarded: back on number entry.
        expect(find.text(en.phoneNumberLabel), findsOneWidget);
        expect(find.text(en.sendCode), findsOneWidget);
      },
    );
  });

  group('signed-in hand-off', () {
    testWidgets('a successful confirm signs in and leaves the phone route', (
      tester,
    ) async {
      final fake = FakeAuthRepository();
      final fakeProfiles = FakeProfileRepository();
      addTearDown(fake.dispose);
      addTearDown(fakeProfiles.dispose);
      await tester.pumpWidget(
        localizedApp(
          const SignInScreen(),
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(flavor: AppFlavor.dev),
            ),
            authRepositoryProvider.overrideWith((ref) => fake),
            profileRepositoryProvider.overrideWith((ref) => fakeProfiles),
          ],
        ),
      );

      await tester.tap(find.text(en.continueWithPhone));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneSignInScreen), findsOneWidget);

      await reachCodeEntry(tester, fake);
      fake.onConfirmPhoneCode = (_, _) async {
        // The real repository surfaces the signed-in user on the auth stream;
        // the fake mirrors that so the global AuthController flips to signed-in.
        fake.emit(testUser);
        return testUser;
      };

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text(en.verifyCode));
      await tester.pumpAndSettle();

      // The pushed phone route pops itself; SignInScreen's rebuilt tree
      // (OnboardingGate → fresh signup) is uncovered.
      expect(find.byType(PhoneSignInScreen), findsNothing);
      expect(find.byType(ProfileCaptureScreen), findsOneWidget);
    });
  });

  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets(
        'renders localized phone copy with RTL from locale ($locale)',
        (tester) async {
          final l10n = l10nFor(locale);
          await pumpPhoneScreen(tester, locale: locale);

          expect(find.text(l10n.continueWithPhone), findsOneWidget);
          expect(find.text(l10n.phoneNumberLabel), findsOneWidget);
          expect(find.text(l10n.sendCode), findsOneWidget);

          // RTL must derive from the locale alone (no manual Directionality).
          final direction = Directionality.of(
            tester.element(find.byType(PhoneSignInScreen)),
          );
          expect(
            direction,
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
