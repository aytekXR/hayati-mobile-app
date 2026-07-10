import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/presentation/partner_preview_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes
// it — same seam golden_harness.dart uses.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_invite_preview_repository.dart';
import '../../../support/fake_invite_repository.dart';
import '../../../support/golden/golden_harness.dart';

// Deterministic fixtures: a fixed inviter name (from the preview fake's default)
// and a fixed code, so the has-code goldens don't drift with data.
final _link = Uri.parse('hayati://invite/ABCD2345');
const _joiner = AuthUser(uid: 'joiner-uid', displayName: 'Deniz');

void main() {
  ({
    FakeAuthRepository auth,
    FakeDeepLinkSource deepLinks,
    FakeInvitePreviewRepository previews,
    FakeInviteRepository invites,
    List<Override> overrides,
  })
  arrange({
    AuthUser? user,
    Uri? link,
    InvitePreviewResult? result,
    Future<InvitePreviewResult> Function(String code)? onPreview,
  }) {
    final auth = FakeAuthRepository(initialUser: user);
    final deepLinks = FakeDeepLinkSource(initialUri: link);
    final previews = FakeInvitePreviewRepository(result: result)
      ..onPreview = onPreview;
    final invites = FakeInviteRepository();
    return (
      auth: auth,
      deepLinks: deepLinks,
      previews: previews,
      invites: invites,
      overrides: [
        authRepositoryProvider.overrideWith((ref) => auth),
        deepLinkSourceProvider.overrideWith((ref) => deepLinks),
        invitePreviewRepositoryProvider.overrideWith((ref) => previews),
        inviteRepositoryProvider.overrideWith((ref) => invites),
      ],
    );
  }

  void tearDownFakes(
    ({
      FakeAuthRepository auth,
      FakeDeepLinkSource deepLinks,
      FakeInvitePreviewRepository previews,
      FakeInviteRepository invites,
      List<Override> overrides,
    })
    fakes,
  ) {
    addTearDown(fakes.auth.dispose);
    addTearDown(fakes.deepLinks.dispose);
    addTearDown(fakes.previews.dispose);
    addTearDown(fakes.invites.dispose);
  }

  // EMPTY: no pending code → manual entry.
  for (final cell in sixCells) {
    testWidgets('empty ${cell.suffix}', (tester) async {
      final fakes = arrange();
      tearDownFakes(fakes);

      await pumpGolden(
        tester,
        const PartnerPreviewScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PartnerPreviewScreen),
        matchesGoldenFile(
          goldenFile('partner_preview_screen', 'empty', cell.suffix),
        ),
      );
    });
  }

  // LOADING: pending code, preview never completes → spinner at t=0.
  for (final cell in sixCells) {
    testWidgets('loading ${cell.suffix}', (tester) async {
      final fakes = arrange(
        user: _joiner,
        link: _link,
        onPreview: (_) => Completer<InvitePreviewResult>().future,
      );
      tearDownFakes(fakes);

      await pumpGolden(
        tester,
        const PartnerPreviewScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      // First pump resolves the cold-start link into the pending code; the
      // second lands the never-completing preview's spinner (t=0, stable).
      await tester.pump();
      await tester.pump();

      await expectLater(
        find.byType(PartnerPreviewScreen),
        matchesGoldenFile(
          goldenFile('partner_preview_screen', 'loading', cell.suffix),
        ),
      );
    });
  }

  // VALID (signed in): the named inviter + join CTA.
  for (final cell in sixCells) {
    testWidgets('valid ${cell.suffix}', (tester) async {
      final fakes = arrange(user: _joiner, link: _link);
      tearDownFakes(fakes);

      await pumpGolden(
        tester,
        const PartnerPreviewScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PartnerPreviewScreen),
        matchesGoldenFile(
          goldenFile('partner_preview_screen', 'valid', cell.suffix),
        ),
      );
    });
  }

  // EXPIRED-OR-UNKNOWN: the single unavailable state.
  for (final cell in sixCells) {
    testWidgets('unavailable ${cell.suffix}', (tester) async {
      final fakes = arrange(
        user: _joiner,
        link: _link,
        result: const InvitePreviewResult(status: InvitePreviewStatus.expired),
      );
      tearDownFakes(fakes);

      await pumpGolden(
        tester,
        const PartnerPreviewScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PartnerPreviewScreen),
        matchesGoldenFile(
          goldenFile('partner_preview_screen', 'unavailable', cell.suffix),
        ),
      );
    });
  }

  // ERROR: the preview FETCH failed (retryable).
  for (final cell in sixCells) {
    testWidgets('error ${cell.suffix}', (tester) async {
      final fakes = arrange(
        user: _joiner,
        link: _link,
        onPreview: (_) async =>
            throw const InviteNetworkException(message: 'offline'),
      );
      tearDownFakes(fakes);

      await pumpGolden(
        tester,
        const PartnerPreviewScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: fakes.overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PartnerPreviewScreen),
        matchesGoldenFile(
          goldenFile('partner_preview_screen', 'error', cell.suffix),
        ),
      );
    });
  }
}
