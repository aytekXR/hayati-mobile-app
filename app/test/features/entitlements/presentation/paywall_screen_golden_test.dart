import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/paywall_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation
// exposes it — same seam the other golden tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/fake_purchases_repository.dart';
import '../../../support/golden/golden_harness.dart';

const _coupleId = 'couple-1';
const _user = AuthUser(uid: 'uid-1', displayName: 'Aytek');

/// Pinned clock so the entitled state's expiry check is deterministic.
final _now = DateTime.utc(2026, 7, 11, 12);

CoupleEntitlement _entitled() => CoupleEntitlement(
  entitled: true,
  expiresAt: _now.add(const Duration(days: 30)),
);

void main() {
  // The default fake serves the one TRY storefront fixture (annual + monthly),
  // so identical price strings render in every locale cell — storefront
  // currency follows the store account, not the device (ADR-014 Decision 4).
  List<Override> arrange({FakeEntitlementRepository? mirrors}) {
    final purchases = FakePurchasesRepository();
    final m = mirrors ?? FakeEntitlementRepository();
    final auth = FakeAuthRepository(initialUser: _user);
    addTearDown(m.dispose);
    addTearDown(auth.dispose);
    return [
      purchasesRepositoryProvider.overrideWith((ref) => purchases),
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

  // Free couple, offerings loaded: the annual-first cards + CTA.
  for (final cell in sixCells) {
    testWidgets('loaded ${cell.suffix}', (tester) async {
      final overrides = arrange();

      await pumpGolden(
        tester,
        const PaywallScreen(coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PaywallScreen),
        matchesGoldenFile(goldenFile('paywall_screen', 'loaded', cell.suffix)),
      );
    });
  }

  // Dynamic-type probe on the loaded state, natural directions only.
  for (final cell in naturalCells) {
    testWidgets('loaded scale130 ${cell.suffix}', (tester) async {
      final overrides = arrange();

      await pumpGolden(
        tester,
        const PaywallScreen(coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PaywallScreen),
        matchesGoldenFile(
          goldenFile('paywall_screen', 'loaded_scale130', cell.suffix),
        ),
      );
    });
  }

  // Already-premium couple: confirmation + restore + manage hint, no buy CTA.
  for (final cell in sixCells) {
    testWidgets('entitled ${cell.suffix}', (tester) async {
      final overrides = arrange(mirrors: entitledMirror());

      await pumpGolden(
        tester,
        const PaywallScreen(coupleId: _coupleId),
        locale: cell.locale,
        direction: cell.direction,
        overrides: overrides,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PaywallScreen),
        matchesGoldenFile(
          goldenFile('paywall_screen', 'entitled', cell.suffix),
        ),
      );
    });
  }
}
