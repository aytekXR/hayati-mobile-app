import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/profile/presentation/name_capture_screen.dart';
import 'package:hayati_app/features/profile/presentation/state/name_capture_done.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_local_flag_store.dart';
import '../../../support/localized_app.dart';

const namedUser = AuthUser(uid: 'uid-1', displayName: 'Aylin');
const phoneUser = AuthUser(uid: 'uid-1');

void main() {
  Future<(FakeAuthRepository, FakeLocalFlagStore)> pumpScreen(
    WidgetTester tester, {
    AuthUser user = phoneUser,
    Locale locale = const Locale('en'),
  }) async {
    final fakeAuth = FakeAuthRepository(initialUser: user);
    final flags = FakeLocalFlagStore();
    addTearDown(fakeAuth.dispose);
    await tester.pumpWidget(
      localizedApp(
        NameCaptureScreen(user: user),
        locale: locale,
        overrides: [
          authRepositoryProvider.overrideWith((ref) => fakeAuth),
          localFlagStoreProvider.overrideWithValue(flags),
        ],
      ),
    );
    return (fakeAuth, flags);
  }

  group('pre-fill (QW-6: Apple/Google users just confirm)', () {
    testWidgets('the field pre-fills from the Auth displayName', (
      tester,
    ) async {
      await pumpScreen(tester, user: namedUser);

      expect(find.widgetWithText(TextField, 'Aylin'), findsOneWidget);
    });

    testWidgets('a phone sign-up (no name) starts empty with Continue '
        'disabled', (tester) async {
      await pumpScreen(tester);

      final en = l10nFor(const Locale('en'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.continueAction),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('continue', () {
    testWidgets('is disabled for whitespace-only entry (trim is the canonical '
        'entry)', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final en = l10nFor(const Locale('en'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.continueAction),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('writes the TRIMMED name to the auth record, then sets the '
        'per-uid done flag', (tester) async {
      final (fakeAuth, flags) = await pumpScreen(tester);

      final en = l10nFor(const Locale('en'));
      await tester.enterText(find.byType(TextField), '  hayatım ');
      await tester.pump();
      await tester.tap(find.text(en.continueAction));
      // Discrete pumps, not pumpAndSettle: on success the screen deliberately
      // stays on its in-flight spinner — in the app the gate swaps it out.
      await tester.pump();
      await tester.pump();

      expect(fakeAuth.updatedDisplayNames, ['hayatım']);
      expect(flags.isSet(nameCaptureDoneKey('uid-1')), isTrue);
    });

    testWidgets('a pre-filled user can tap straight through (confirm-only '
        'path)', (tester) async {
      final (fakeAuth, flags) = await pumpScreen(tester, user: namedUser);

      final en = l10nFor(const Locale('en'));
      await tester.tap(find.text(en.continueAction));
      await tester.pump();
      await tester.pump();

      expect(fakeAuth.updatedDisplayNames, ['Aylin']);
      expect(flags.isSet(nameCaptureDoneKey('uid-1')), isTrue);
    });
  });

  group('save failure (the profile-save retry contract)', () {
    testWidgets('a network failure shows the honest retry line and does NOT '
        'set the done flag', (tester) async {
      final (fakeAuth, flags) = await pumpScreen(tester);
      fakeAuth.onUpdateDisplayName = (_) async =>
          throw const AuthNetworkException(message: 'off');

      final en = l10nFor(const Locale('en'));
      await tester.enterText(find.byType(TextField), 'Aytek');
      await tester.pump();
      await tester.tap(find.text(en.continueAction));
      await tester.pumpAndSettle();

      expect(find.text(en.errorNetworkRetry), findsOneWidget);
      expect(flags.isSet(nameCaptureDoneKey('uid-1')), isFalse);

      // Retry after the failure clears: the flag lands and the error goes.
      fakeAuth.onUpdateDisplayName = null;
      await tester.tap(find.text(en.continueAction));
      await tester.pump();
      await tester.pump();

      expect(find.text(en.errorNetworkRetry), findsNothing);
      expect(flags.isSet(nameCaptureDoneKey('uid-1')), isTrue);
    });

    testWidgets('an unclassified failure shows the generic line', (
      tester,
    ) async {
      final (fakeAuth, _) = await pumpScreen(tester);
      fakeAuth.onUpdateDisplayName = (_) async =>
          throw const AuthUnknownException(code: 'boom');

      final en = l10nFor(const Locale('en'));
      await tester.enterText(find.byType(TextField), 'Aytek');
      await tester.pump();
      await tester.tap(find.text(en.continueAction));
      await tester.pumpAndSettle();

      expect(find.text(en.errorGeneric), findsOneWidget);
    });
  });

  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets('renders title, helper, hint and CTA localized ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        await pumpScreen(tester, locale: locale);

        expect(find.text(l10n.nameCaptureTitle), findsOneWidget);
        expect(find.text(l10n.nameCaptureHelper), findsOneWidget);
        expect(find.text(l10n.nameCaptureHint), findsOneWidget);
        expect(find.text(l10n.continueAction), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(NameCaptureScreen))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
