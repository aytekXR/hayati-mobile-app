import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/pack_selection_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation
// exposes it — same seam the other golden tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/golden/golden_harness.dart';

const _coupleId = 'couple-1';
const _user = AuthUser(uid: 'uid-1', displayName: 'Aytek');

/// Pinned clock so the unlocked state's expiry check is deterministic.
final _now = DateTime.utc(2026, 7, 11, 12);

CoupleEntitlement _entitled() => CoupleEntitlement(
  entitled: true,
  expiresAt: _now.add(const Duration(days: 30)),
);

void main() {
  List<Override> arrange({FakeEntitlementRepository? mirrors}) {
    final m = mirrors ?? FakeEntitlementRepository();
    final auth = FakeAuthRepository(initialUser: _user);
    addTearDown(m.dispose);
    addTearDown(auth.dispose);
    return [
      entitlementRepositoryProvider.overrideWith((ref) => m),
      authRepositoryProvider.overrideWith((ref) => auth),
      soloClockProvider.overrideWith(
        (ref) =>
            () => _now,
      ),
    ];
  }

  FakeEntitlementRepository entitledMirror() =>
      FakeEntitlementRepository(initialMirrors: {_coupleId: _entitled()});

  // Free couple: the lock + premium pitch + CTA (state named `gated`, not
  // `locked` — that word means partner-slot-locked on the paired home).
  for (final cell in sixCells) {
    testWidgets('gated ${cell.suffix}', (tester) async {
      final overrides = arrange();

      await pumpGolden(
        tester,
        const PackSelectionScreen(coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PackSelectionScreen),
        matchesGoldenFile(
          goldenFile('pack_selection_screen', 'gated', cell.suffix),
        ),
      );
    });
  }

  // Dynamic-type probe on the gated state, natural directions only.
  for (final cell in naturalCells) {
    testWidgets('gated scale130 ${cell.suffix}', (tester) async {
      final overrides = arrange();

      await pumpGolden(
        tester,
        const PackSelectionScreen(coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PackSelectionScreen),
        matchesGoldenFile(
          goldenFile('pack_selection_screen', 'gated_scale130', cell.suffix),
        ),
      );
    });
  }

  // Premium couple: the current-bank card presented honestly.
  for (final cell in sixCells) {
    testWidgets('unlocked ${cell.suffix}', (tester) async {
      final overrides = arrange(mirrors: entitledMirror());

      await pumpGolden(
        tester,
        const PackSelectionScreen(coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PackSelectionScreen),
        matchesGoldenFile(
          goldenFile('pack_selection_screen', 'unlocked', cell.suffix),
        ),
      );
    });
  }
}
