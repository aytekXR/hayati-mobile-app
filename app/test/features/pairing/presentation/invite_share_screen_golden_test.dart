import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';
import 'package:hayati_app/features/pairing/domain/issued_invite.dart';
import 'package:hayati_app/features/pairing/presentation/invite_share_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes
// it — same seam localized_app.dart / golden_harness.dart use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_invite_repository.dart';
import '../../../support/fake_invite_share_launcher.dart';
import '../../../support/golden/golden_harness.dart';

// Fixed code + expiry so the has-code goldens are deterministic (the expiry
// line formats these exact wall-clock fields regardless of the host timezone).
final _fixedInvite = IssuedInvite(
  code: 'ABCD2345',
  expiresAt: DateTime(2026, 7, 11, 15, 30),
  reused: false,
);

void main() {
  ({
    FakeInviteRepository invites,
    FakeInviteShareLauncher launcher,
    FakeAuthRepository auth,
    List<Override> overrides,
  })
  arrange({Future<IssuedInvite> Function()? onCreateInvite}) {
    final invites = FakeInviteRepository(invite: _fixedInvite)
      ..onCreateInvite = onCreateInvite;
    final launcher = FakeInviteShareLauncher();
    final auth = FakeAuthRepository();
    return (
      invites: invites,
      launcher: launcher,
      auth: auth,
      overrides: [
        inviteRepositoryProvider.overrideWith((ref) => invites),
        inviteShareLauncherProvider.overrideWith((ref) => launcher),
        authRepositoryProvider.overrideWith((ref) => auth),
      ],
    );
  }

  for (final cell in sixCells) {
    testWidgets('has-code ${cell.suffix}', (tester) async {
      final fakes = arrange();
      addTearDown(fakes.invites.dispose);
      addTearDown(fakes.launcher.dispose);
      addTearDown(fakes.auth.dispose);

      await pumpGolden(
        tester,
        const InviteShareScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(InviteShareScreen),
        matchesGoldenFile(
          goldenFile('invite_share_screen', 'has_code', cell.suffix),
        ),
      );
    });
  }

  for (final cell in sixCells) {
    testWidgets('loading ${cell.suffix}', (tester) async {
      // Never-completing issue → the screen holds its loading state. Pump a
      // single zero-duration frame so the spinner is captured at t=0
      // (deterministic), never pumpAndSettle (it would hang).
      final fakes = arrange(
        onCreateInvite: () => Completer<IssuedInvite>().future,
      );
      addTearDown(fakes.invites.dispose);
      addTearDown(fakes.launcher.dispose);
      addTearDown(fakes.auth.dispose);

      await pumpGolden(
        tester,
        const InviteShareScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pump();

      await expectLater(
        find.byType(InviteShareScreen),
        matchesGoldenFile(
          goldenFile('invite_share_screen', 'loading', cell.suffix),
        ),
      );
    });
  }

  for (final cell in sixCells) {
    testWidgets('error ${cell.suffix}', (tester) async {
      final fakes = arrange(
        onCreateInvite: () async => throw const _StubFailure(),
      );
      addTearDown(fakes.invites.dispose);
      addTearDown(fakes.launcher.dispose);
      addTearDown(fakes.auth.dispose);

      await pumpGolden(
        tester,
        const InviteShareScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(InviteShareScreen),
        matchesGoldenFile(
          goldenFile('invite_share_screen', 'error', cell.suffix),
        ),
      );
    });
  }
}

// Any thrown object drives the screen's single error surface; a trivial stand-in
// keeps the golden focused on the localized failure copy, not the error type.
class _StubFailure implements Exception {
  const _StubFailure();
}
