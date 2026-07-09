import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/presentation/partner_preview_screen.dart';
import 'package:hayati_app/features/pairing/presentation/state/pending_invite.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_invite_preview_repository.dart';
import '../../../support/fake_invite_repository.dart';
import '../../../support/localized_app.dart';

const _code = 'ABCD2345';
const _user = AuthUser(uid: 'joiner-uid', displayName: 'Deniz');

void main() {
  final en = l10nFor(const Locale('en'));

  // Arranges the four seams the screen touches (deep link, preview, join
  // callable, auth) and pumps it as the app's home route. A non-null
  // [initialLink] seeds the pending deep-link code; otherwise the screen opens
  // on the manual-entry empty state.
  Future<({FakeInviteRepository invites, FakeInvitePreviewRepository previews})>
  pumpScreen(
    WidgetTester tester, {
    AuthUser? initialUser,
    Uri? initialLink,
    InvitePreviewResult? previewResult,
    Future<InvitePreviewResult> Function(String code)? onPreview,
    Future<String> Function(String code)? onJoin,
    Locale locale = const Locale('en'),
  }) async {
    final auth = FakeAuthRepository(initialUser: initialUser);
    final deepLinks = FakeDeepLinkSource(initialUri: initialLink);
    final previews = FakeInvitePreviewRepository(result: previewResult)
      ..onPreview = onPreview;
    final invites = FakeInviteRepository()..onJoinInvite = onJoin;
    addTearDown(auth.dispose);
    addTearDown(deepLinks.dispose);
    addTearDown(previews.dispose);
    addTearDown(invites.dispose);

    await tester.pumpWidget(
      localizedApp(
        const PartnerPreviewScreen(),
        locale: locale,
        overrides: [
          authRepositoryProvider.overrideWith((ref) => auth),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
          invitePreviewRepositoryProvider.overrideWith((ref) => previews),
          inviteRepositoryProvider.overrideWith((ref) => invites),
        ],
      ),
    );
    return (invites: invites, previews: previews);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(PartnerPreviewScreen)),
      );

  group('empty state (manual entry)', () {
    testWidgets('with no pending code, invites the user to enter one', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text(en.joinHaveCodeTitle), findsOneWidget);
      expect(find.text(en.joinHaveCodeBody), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(en.joinCheckCode), findsOneWidget);
    });

    testWidgets(
      'an off-alphabet / wrong-length entry shows inline validation',
      (tester) async {
        await pumpScreen(tester);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'nope');
        await tester.tap(find.text(en.joinCheckCode));
        await tester.pump();

        expect(find.text(en.inviteCodeInvalid), findsOneWidget);
        // Still on entry — no preview fetched.
        expect(find.text(en.joinHaveCodeTitle), findsOneWidget);
      },
    );

    testWidgets('a valid (case-insensitive) entry moves to the preview', (
      tester,
    ) async {
      final fakes = await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abcd2345');
      await tester.tap(find.text(en.joinCheckCode));
      await tester.pumpAndSettle();

      // The normalized (uppercased) code is what the preview seam receives.
      expect(fakes.previews.previewedCodes, ['ABCD2345']);
      expect(find.text(en.invitePreviewInvitedBy('Aylin')), findsOneWidget);
    });

    testWidgets('the validation line clears as the user edits', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text(en.joinCheckCode));
      await tester.pump();
      expect(find.text(en.inviteCodeInvalid), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'noper');
      await tester.pump();
      expect(find.text(en.inviteCodeInvalid), findsNothing);
    });
  });

  group('loading state', () {
    testWidgets('shows a spinner while the preview is in flight', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLink: Uri.parse('hayati://invite/$_code'),
        onPreview: (_) => Completer<InvitePreviewResult>().future,
      );
      // Let the cold-start link resolve into the pending code, then the never-
      // completing preview holds the spinner (pump, never pumpAndSettle).
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('valid preview', () {
    testWidgets('names the inviter and, signed in, offers the join CTA', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialUser: _user,
        initialLink: Uri.parse('hayati://invite/$_code'),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.invitePreviewInvitedBy('Aylin')), findsOneWidget);
      expect(find.text(en.invitePreviewValidBody), findsOneWidget);
      expect(find.text(en.joinAcceptButton), findsOneWidget);
    });

    testWidgets('falls back gracefully when the server resolved no name', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialUser: _user,
        initialLink: Uri.parse('hayati://invite/$_code'),
        previewResult: const InvitePreviewResult(
          status: InvitePreviewStatus.valid,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.invitePreviewInvitedBySomeone), findsOneWidget);
    });

    testWidgets('signed OUT, the join CTA is the shared sign-in actions', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLink: Uri.parse('hayati://invite/$_code'),
      );
      await tester.pumpAndSettle();

      // The invitee sees who invited them, then the sign-in choice — not a join
      // button they cannot yet use.
      expect(find.text(en.continueWithApple), findsOneWidget);
      expect(find.text(en.continueWithGoogle), findsOneWidget);
      expect(find.text(en.continueWithPhone), findsOneWidget);
      expect(find.text(en.joinAcceptButton), findsNothing);
    });
  });

  group('join (signed in)', () {
    testWidgets('tapping Accept redeems the code and clears the pending '
        'invite on success', (tester) async {
      final fakes = await pumpScreen(
        tester,
        initialUser: _user,
        initialLink: Uri.parse('hayati://invite/$_code'),
      );
      await tester.pumpAndSettle();
      final container = containerOf(tester);
      expect(container.read(pendingInviteProvider), _code);

      await tester.tap(find.text(en.joinAcceptButton));
      await tester.pumpAndSettle();

      expect(fakes.invites.joinedCodes, [_code]);
      // Success is a hand-off: the pending invite is cleared (the users-doc
      // stream re-routes the gate elsewhere).
      expect(container.read(pendingInviteProvider), isNull);
    });

    testWidgets(
      'while a join is in flight the CTA disables and shows progress',
      (tester) async {
        await pumpScreen(
          tester,
          initialUser: _user,
          initialLink: Uri.parse('hayati://invite/$_code'),
          onJoin: (_) => Completer<String>().future, // never settles
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(en.joinAcceptButton));
        await tester.pump();

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
        expect(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
      },
    );

    // Every sealed join failure maps to its own honest copy; terminal-code
    // failures swap the Accept button for a re-entry, retryable ones keep it.
    final cases =
        <({InviteException error, String Function() copy, bool terminal})>[
          (
            error: const InviteJoinUnknownCodeException(),
            copy: () => en.joinErrorUnknownCode,
            terminal: true,
          ),
          (
            error: const InviteJoinExpiredException(),
            copy: () => en.joinErrorExpired,
            terminal: true,
          ),
          (
            error: const InviteJoinConsumedException(),
            copy: () => en.joinErrorConsumed,
            terminal: true,
          ),
          (
            error: const InviteJoinSelfJoinException(),
            copy: () => en.joinErrorSelfJoin,
            terminal: true,
          ),
          (
            error: const InviteJoinAlreadyPairedException(),
            copy: () => en.joinErrorAlreadyPaired,
            terminal: true,
          ),
          (
            error: const InviteJoinProfileMissingException(),
            copy: () => en.joinErrorProfileMissing,
            terminal: false,
          ),
          (
            error: const InviteNetworkException(message: 'off'),
            copy: () => en.errorNetworkRetry,
            terminal: false,
          ),
          (
            error: const InvitePermissionException(message: 'stale'),
            copy: () => en.errorGeneric,
            terminal: false,
          ),
        ];

    for (final c in cases) {
      testWidgets('${c.error.runtimeType} shows its honest copy', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          initialUser: _user,
          initialLink: Uri.parse('hayati://invite/$_code'),
          onJoin: (_) async => throw c.error,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(en.joinAcceptButton));
        await tester.pumpAndSettle();

        expect(find.text(c.copy()), findsOneWidget);
        if (c.terminal) {
          // This code will never work → re-entry replaces Accept.
          expect(find.text(en.joinEnterAnotherCode), findsOneWidget);
          expect(find.text(en.joinAcceptButton), findsNothing);
        } else {
          expect(find.text(en.joinAcceptButton), findsOneWidget);
        }
      });
    }

    testWidgets('a terminal failure re-entry returns to manual entry', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialUser: _user,
        initialLink: Uri.parse('hayati://invite/$_code'),
        onJoin: (_) async => throw const InviteJoinConsumedException(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.joinAcceptButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.joinEnterAnotherCode));
      await tester.pumpAndSettle();

      expect(find.text(en.joinHaveCodeTitle), findsOneWidget);
      expect(containerOf(tester).read(pendingInviteProvider), isNull);
    });
  });

  group('expired-or-unknown state', () {
    for (final status in [
      InvitePreviewStatus.expired,
      InvitePreviewStatus.unknown,
    ]) {
      testWidgets('$status shows the single unavailable state', (tester) async {
        await pumpScreen(
          tester,
          initialUser: _user,
          initialLink: Uri.parse('hayati://invite/$_code'),
          previewResult: InvitePreviewResult(status: status),
        );
        await tester.pumpAndSettle();

        expect(find.text(en.invitePreviewUnavailableTitle), findsOneWidget);
        expect(find.text(en.invitePreviewUnavailableBody), findsOneWidget);

        await tester.tap(find.text(en.joinEnterAnotherCode));
        await tester.pumpAndSettle();
        expect(find.text(en.joinHaveCodeTitle), findsOneWidget);
      });
    }
  });

  group('preview error state', () {
    testWidgets('a fetch failure shows retry copy and invalidate re-fetches', (
      tester,
    ) async {
      final fakes = await pumpScreen(
        tester,
        initialUser: _user,
        initialLink: Uri.parse('hayati://invite/$_code'),
        onPreview: (_) async =>
            throw const InviteNetworkException(message: 'x'),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.invitePreviewFailedBody), findsOneWidget);
      expect(find.text(en.tryAgain), findsOneWidget);
      expect(fakes.previews.previewCalls, 1);

      fakes.previews.onPreview = null; // the retry succeeds
      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();

      expect(fakes.previews.previewCalls, 2);
      expect(find.text(en.invitePreviewInvitedBy('Aylin')), findsOneWidget);
    });
  });

  group('dismiss (post-auth)', () {
    testWidgets('"not now" clears the pending invite', (tester) async {
      await pumpScreen(
        tester,
        initialUser: _user,
        initialLink: Uri.parse('hayati://invite/$_code'),
      );
      await tester.pumpAndSettle();
      final container = containerOf(tester);
      expect(container.read(pendingInviteProvider), _code);

      await tester.tap(find.text(en.joinSkipForNow));
      await tester.pumpAndSettle();

      expect(container.read(pendingInviteProvider), isNull);
    });
  });

  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets('renders the valid preview localized ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        await pumpScreen(
          tester,
          initialUser: _user,
          initialLink: Uri.parse('hayati://invite/$_code'),
          locale: locale,
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.invitePreviewInvitedBy('Aylin')), findsOneWidget);
        expect(find.text(l10n.joinAcceptButton), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(PartnerPreviewScreen))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
