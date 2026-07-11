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
