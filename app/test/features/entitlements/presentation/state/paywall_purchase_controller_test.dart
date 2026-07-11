import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchase_exception.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/state/paywall_purchase_controller.dart';
import 'package:hayati_app/features/entitlements/presentation/state/pending_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../support/fake_entitlement_repository.dart';
import '../../../../support/fake_purchases_repository.dart';
import '../../../../support/purchases_fixtures.dart';

void main() {
  const coupleId = 'couple-1';

  (ProviderContainer, FakePurchasesRepository) arrange([
    FakePurchasesRepository? purchases,
  ]) {
    final repo = purchases ?? FakePurchasesRepository();
    final mirrors = FakeEntitlementRepository();
    final container = ProviderContainer(
      overrides: [
        purchasesRepositoryProvider.overrideWith((ref) => repo),
        entitlementRepositoryProvider.overrideWith((ref) => mirrors),
        soloClockProvider.overrideWith(
          (ref) =>
              () => DateTime.utc(2026, 7, 11, 12),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(mirrors.dispose);
    return (container, repo);
  }

  PaywallPurchaseState state(ProviderContainer container) =>
      container.read(paywallPurchaseControllerProvider(coupleId: coupleId));

  PaywallPurchaseController controllerOf(ProviderContainer container) =>
      container.read(
        paywallPurchaseControllerProvider(coupleId: coupleId).notifier,
      );

  bool pending(ProviderContainer container) =>
      container.read(pendingPurchaseProvider(coupleId: coupleId));

  test('starts idle', () {
    final (container, _) = arrange();
    expect(state(container), isA<PaywallPurchaseIdle>());
  });

  test('a happy purchase marks pending and returns to idle', () async {
    final (container, purchases) = arrange();

    await controllerOf(container).purchase(anAnnualPackage());

    expect(state(container), isA<PaywallPurchaseIdle>());
    expect(pending(container), isTrue);
    expect(purchases.callLog, contains('purchase:rc_annual'));
  });

  test('a cancel returns to idle silently (no failure, not marked)', () async {
    final (container, _) = arrange(
      FakePurchasesRepository()
        ..onPurchase = (_) async => throw const PurchaseCancelledException(),
    );

    await controllerOf(container).purchase(anAnnualPackage());

    expect(state(container), isA<PaywallPurchaseIdle>());
    expect(pending(container), isFalse);
  });

  test('a typed failure surfaces as PaywallPurchaseFailure', () async {
    final (container, _) = arrange(
      FakePurchasesRepository()
        ..onPurchase = (_) async => throw const PurchaseStoreException(),
    );

    await controllerOf(container).purchase(anAnnualPackage());

    final current = state(container);
    expect(current, isA<PaywallPurchaseFailure>());
    expect(
      (current as PaywallPurchaseFailure).exception,
      const PurchaseStoreException(),
    );
  });

  test('re-entrant purchases are dropped while one is in flight', () async {
    final gate = Completer<CustomerInfo>();
    final (container, purchases) = arrange(
      FakePurchasesRepository()..onPurchase = (_) => gate.future,
    );
    final controller = controllerOf(container);

    final first = controller.purchase(anAnnualPackage());
    expect(state(container), isA<PaywallPurchaseInFlight>());

    await controller.purchase(anAnnualPackage()); // dropped

    gate.complete(aCustomerInfo());
    await first;

    expect(
      purchases.callLog.where((e) => e.startsWith('purchase')),
      hasLength(1),
    );
    expect(state(container), isA<PaywallPurchaseIdle>());
  });

  test('a happy restore marks pending and returns to idle', () async {
    final (container, purchases) = arrange();

    await controllerOf(container).restore();

    expect(state(container), isA<PaywallPurchaseIdle>());
    expect(pending(container), isTrue);
    expect(purchases.callLog, contains('restore'));
  });

  test('dismissError clears a failure back to idle', () async {
    final (container, _) = arrange(
      FakePurchasesRepository()
        ..onPurchase = (_) async => throw const PurchaseStoreException(),
    );
    final controller = controllerOf(container);
    await controller.purchase(anAnnualPackage());
    expect(state(container), isA<PaywallPurchaseFailure>());

    controller.dismissError();

    expect(state(container), isA<PaywallPurchaseIdle>());
  });
}
