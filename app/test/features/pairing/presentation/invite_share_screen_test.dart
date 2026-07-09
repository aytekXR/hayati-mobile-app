import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';
import 'package:hayati_app/features/pairing/presentation/invite_share_screen.dart';
import 'package:hayati_app/features/pairing/presentation/partner_preview_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_invite_preview_repository.dart';
import '../../../support/fake_invite_repository.dart';
import '../../../support/fake_invite_share_launcher.dart';
import '../../../support/localized_app.dart';

void main() {
  (FakeInviteRepository, FakeInviteShareLauncher) makeFakes() =>
      (FakeInviteRepository(), FakeInviteShareLauncher());

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeInviteRepository invites,
    FakeInviteShareLauncher launcher, {
    Locale locale = const Locale('en'),
  }) async {
    final auth = FakeAuthRepository();
    // The "Have a code?" affordance pushes PartnerPreviewScreen, which watches
    // pendingInviteProvider → deepLinkSourceProvider and the preview seam; an
    // empty deep-link source lands it on the manual-entry state.
    final deepLinks = FakeDeepLinkSource();
    final previews = FakeInvitePreviewRepository();
    addTearDown(invites.dispose);
    addTearDown(launcher.dispose);
    addTearDown(auth.dispose);
    addTearDown(deepLinks.dispose);
    addTearDown(previews.dispose);
    await tester.pumpWidget(
      localizedApp(
        const InviteShareScreen(),
        locale: locale,
        overrides: [
          inviteRepositoryProvider.overrideWith((ref) => invites),
          inviteShareLauncherProvider.overrideWith((ref) => launcher),
          authRepositoryProvider.overrideWith((ref) => auth),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
          invitePreviewRepositoryProvider.overrideWith((ref) => previews),
        ],
      ),
    );
  }

  testWidgets('shows a spinner while the invite is being issued', (
    tester,
  ) async {
    final (invites, launcher) = makeFakes();
    invites.onCreateInvite = () => Completer<Never>().future; // never settles
    await pumpScreen(tester, invites, launcher);

    // A microtask lets build() start; the never-completing future keeps it in
    // the loading state.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text(l10nFor(const Locale('en')).inviteShareButton),
      findsNothing,
    );
  });

  group('share affordance', () {
    for (final locale in supportedTestLocales) {
      testWidgets('shares the code + deep link message ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        final (invites, launcher) = makeFakes();
        await pumpScreen(tester, invites, launcher, locale: locale);
        await tester.pumpAndSettle();

        // The code from the fake invite is shown prominently.
        expect(find.text('ABCD2345'), findsOneWidget);

        await tester.tap(find.text(l10n.inviteShareButton));
        await tester.pump();

        expect(launcher.sharedMessages, hasLength(1));
        final message = launcher.sharedMessages.single;
        expect(message, contains('ABCD2345'));
        expect(message, contains('hayati://invite/ABCD2345'));
        // The composed message is exactly the localized template.
        expect(
          message,
          l10n.inviteShareMessage('ABCD2345', 'hayati://invite/ABCD2345'),
        );
      });
    }
  });

  group('have-a-code affordance', () {
    testWidgets('opens the partner preview / manual-entry screen', (
      tester,
    ) async {
      final l10n = l10nFor(const Locale('en'));
      final (invites, launcher) = makeFakes();
      await pumpScreen(tester, invites, launcher);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.joinHaveCodeAction));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerPreviewScreen), findsOneWidget);
      // No pending code → manual entry.
      expect(find.text(l10n.joinHaveCodeTitle), findsOneWidget);
    });
  });

  group('error state', () {
    testWidgets('shows the failure copy and retrying re-issues the invite', (
      tester,
    ) async {
      final l10n = l10nFor(const Locale('en'));
      final (invites, launcher) = makeFakes();
      invites.onCreateInvite = () async {
        throw const InviteNetworkException(message: 'offline');
      };
      await pumpScreen(tester, invites, launcher);
      await tester.pumpAndSettle();

      expect(find.text(l10n.inviteLoadFailedBody), findsOneWidget);
      expect(find.text(l10n.tryAgain), findsOneWidget);
      expect(invites.createCalls, 1);

      invites.onCreateInvite = null; // the retry succeeds
      await tester.tap(find.text(l10n.tryAgain));
      await tester.pumpAndSettle();

      expect(invites.createCalls, 2);
      expect(find.text('ABCD2345'), findsOneWidget);
      expect(find.text(l10n.inviteLoadFailedBody), findsNothing);
    });
  });
}
