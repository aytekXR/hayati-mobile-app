import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/pack_selection_screen.dart';
import 'package:hayati_app/features/entitlements/presentation/paywall_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation
// exposes it — the seam the other tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/fake_purchases_repository.dart';
import '../../../support/localized_app.dart';

const _coupleId = 'couple-1';
const _user = AuthUser(uid: 'uid-1', displayName: 'Aytek');
final _now = DateTime.utc(2026, 7, 11, 12);

CoupleEntitlement _entitled({DateTime? expiresAt}) => CoupleEntitlement(
  entitled: true,
  expiresAt: expiresAt ?? _now.add(const Duration(days: 30)),
);

void main() {
  final en = l10nFor(const Locale('en'));

  ({
    List<Override> overrides,
    FakeEntitlementRepository mirrors,
    FakeAuthRepository auth,
  })
  arrange({FakeEntitlementRepository? mirrors, FakeAuthRepository? auth}) {
    final m = mirrors ?? FakeEntitlementRepository();
    final a = auth ?? FakeAuthRepository(initialUser: _user);
    addTearDown(m.dispose);
    addTearDown(a.dispose);
    return (
      overrides: [
        entitlementRepositoryProvider.overrideWith((ref) => m),
        authRepositoryProvider.overrideWith((ref) => a),
        // The gated CTA can push the paywall, which resolves the seam.
        purchasesRepositoryProvider.overrideWith(
          (ref) => FakePurchasesRepository(),
        ),
        soloClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
      mirrors: m,
      auth: a,
    );
  }

  Future<void> pumpPack(WidgetTester tester, List<Override> overrides) {
    return tester.pumpWidget(
      localizedApp(
        const PackSelectionScreen(coupleId: _coupleId),
        overrides: overrides,
      ),
    );
  }

  testWidgets('a free couple sees the gated view with the paywall CTA', (
    tester,
  ) async {
    final env = arrange(); // empty mirror → free
    await pumpPack(tester, env.overrides);
    await tester.pumpAndSettle();

    expect(find.text(en.packSelectionGatedTitle), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, en.packSelectionGatedCta),
      findsOneWidget,
    );
    expect(find.text(en.packSelectionCurrentTitle), findsNothing);
  });

  testWidgets('tapping the gated CTA pushes the paywall', (tester) async {
    final env = arrange();
    await pumpPack(tester, env.overrides);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, en.packSelectionGatedCta),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('a premium couple sees the unlocked view', (tester) async {
    final env = arrange(
      mirrors: FakeEntitlementRepository(
        initialMirrors: {_coupleId: _entitled()},
      ),
    );
    await pumpPack(tester, env.overrides);
    await tester.pumpAndSettle();

    expect(find.text(en.packSelectionCurrentTitle), findsOneWidget);
    expect(find.text(en.packSelectionCurrentBody), findsOneWidget);
    expect(find.text(en.packSelectionComing), findsOneWidget);
    expect(find.text(en.packSelectionGatedTitle), findsNothing);
  });

  testWidgets('the live mirror flips the gate BOTH directions through the real '
      'chain: free → unlocked → gated (delayed expiry)', (tester) async {
    final env = arrange(); // free
    await pumpPack(tester, env.overrides);
    await tester.pumpAndSettle();
    expect(find.text(en.packSelectionGatedTitle), findsOneWidget);

    // The webhook writes an entitled, unexpired mirror → unlocked.
    env.mirrors.emit(_coupleId, _entitled());
    await tester.pumpAndSettle();
    expect(find.text(en.packSelectionCurrentTitle), findsOneWidget);
    expect(find.text(en.packSelectionGatedTitle), findsNothing);

    // A delayed EXPIRATION (entitled:true, expiresAt in the past) downgrades
    // through the real isPremium expiry check → gated again.
    env.mirrors.emit(
      _coupleId,
      _entitled(expiresAt: _now.subtract(const Duration(minutes: 1))),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.packSelectionGatedTitle), findsOneWidget);
    expect(find.text(en.packSelectionCurrentTitle), findsNothing);
  });

  // PRD F4 "gift-your-partner purchase flow", pinned (ADR-015 Decision 6).
  // There is no store gifting mechanism for auto-renewable subscriptions — the
  // GIFT IS THE PURCHASE: one partner pays, the webhook mirrors the entitlement
  // onto the COUPLE, and the OTHER partner's app unlocks without them ever
  // seeing a paywall, a price, or a purchase. This test is the F4 promise as a
  // regression: it goes red the day premium stops being couple-scoped.
  testWidgets('the gift IS the purchase: the NON-purchasing partner unlocks off '
      'their partner’s purchase, never touching the paywall', (tester) async {
    // Partner B's device. B never purchases: the purchases seam's call log must
    // stay empty, and the paywall must never mount.
    final purchases = FakePurchasesRepository();
    final mirrors = FakeEntitlementRepository();
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: 'uid-partner-b', displayName: 'Partner'),
    );
    addTearDown(mirrors.dispose);
    addTearDown(auth.dispose);

    await pumpPack(tester, [
      entitlementRepositoryProvider.overrideWith((ref) => mirrors),
      authRepositoryProvider.overrideWith((ref) => auth),
      purchasesRepositoryProvider.overrideWith((ref) => purchases),
      soloClockProvider.overrideWith(
        (ref) =>
            () => _now,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(en.packSelectionGatedTitle), findsOneWidget);

    // Partner A buys on their OWN device: the only thing that reaches B is the
    // couple's entitlement mirror.
    mirrors.emit(_coupleId, _entitled());
    await tester.pumpAndSettle();

    // B is premium — with no paywall, and no purchase call on B's device.
    expect(find.text(en.packSelectionCurrentTitle), findsOneWidget);
    expect(find.text(en.packSelectionGatedTitle), findsNothing);
    expect(find.byType(PaywallScreen), findsNothing);
    expect(purchases.callLog, isEmpty);
  });

  testWidgets('a remote sign-out pops the pushed pack selection', (
    tester,
  ) async {
    final auth = FakeAuthRepository(initialUser: _user);
    final env = arrange(auth: auth);
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const PackSelectionScreen(coupleId: _coupleId),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: env.overrides,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PackSelectionScreen), findsOneWidget);

    auth.emit(null);
    await tester.pumpAndSettle();
    expect(find.byType(PackSelectionScreen), findsNothing);
  });
}
