import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';

import '../../../support/fake_auth_repository.dart';

const testUser = AuthUser(uid: 'uid-1', displayName: 'Aytek');

void main() {
  Future<FakeAuthRepository> pumpScreen(
    WidgetTester tester, {
    AuthUser? initialUser,
    TextDirection direction = TextDirection.ltr,
  }) async {
    final fake = FakeAuthRepository(initialUser: initialUser);
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: AppFlavor.dev),
          ),
          authRepositoryProvider.overrideWith((ref) => fake),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              Directionality(textDirection: direction, child: child!),
          home: const SignInScreen(),
        ),
      ),
    );
    return fake;
  }

  group('signed-out content state', () {
    testWidgets('shows the brand title and the Google button', (tester) async {
      await pumpScreen(tester);

      expect(find.text(kBrandName), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tapping the button starts the Google flow', (tester) async {
      final fake = await pumpScreen(tester);
      final completer = Completer<AuthUser>();
      fake.onSignInWithGoogle = () => completer.future;

      await tester.tap(find.text('Continue with Google'));
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

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);

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

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Sign-in failed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      fake.onSignInWithGoogle = () async => testUser;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(fake.signInCalls, 2);
      expect(find.text('Aytek'), findsOneWidget);
    });

    testWidgets('network failures get retry-specific copy', (tester) async {
      final fake = await pumpScreen(tester);
      fake.onSignInWithGoogle = () async {
        throw const AuthNetworkException(message: 'offline');
      };

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Check your connection and try again.'), findsOneWidget);
    });

    testWidgets('unknown failures get generic copy', (tester) async {
      final fake = await pumpScreen(tester);
      fake.onSignInWithGoogle = () async {
        throw const AuthUnknownException(code: 'internal-error');
      };

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('signed-in state', () {
    testWidgets('shows the user and signs out', (tester) async {
      final fake = await pumpScreen(tester, initialUser: testUser);

      expect(find.text('Aytek'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(fake.signOutCalls, 1);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('falls back to the email when no display name', (tester) async {
      await pumpScreen(
        tester,
        initialUser: const AuthUser(uid: 'uid-2', email: 'a@example.com'),
      );

      expect(find.text('a@example.com'), findsOneWidget);
    });
  });

  group('RTL', () {
    testWidgets('renders every state under right-to-left', (tester) async {
      final fake = await pumpScreen(tester, direction: TextDirection.rtl);
      expect(find.text('Continue with Google'), findsOneWidget);

      fake.onSignInWithGoogle = () async {
        throw const AuthUnknownException(code: 'internal-error');
      };
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
