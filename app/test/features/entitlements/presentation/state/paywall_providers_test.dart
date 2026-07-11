import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/domain/purchase_exception.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/state/paywall_providers.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../support/fake_purchases_repository.dart';

void main() {
  ProviderContainer arrange(FakePurchasesRepository purchases) {
    final container = ProviderContainer(
      overrides: [purchasesRepositoryProvider.overrideWith((ref) => purchases)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads then resolves to the derived annual-first offering', () async {
    final container = arrange(FakePurchasesRepository());
    container.listen(paywallOfferingProvider, (_, _) {});

    expect(container.read(paywallOfferingProvider).isLoading, isTrue);

    final offering = await container.read(paywallOfferingProvider.future);
    expect(offering.packages.map((p) => p.packageType), [
      PackageType.annual,
      PackageType.monthly,
    ]);
  });

  test(
    'a PurchaseNetworkException surfaces as an AsyncError carrying it',
    () async {
      final container = arrange(
        FakePurchasesRepository()
          ..onFetchOfferings = () async =>
              throw const PurchaseNetworkException(),
      );
      container.listen(paywallOfferingProvider, (_, _) {});
      await pumpEventQueue();

      final snap = container.read(paywallOfferingProvider);
      expect(snap.hasError, isTrue);
      expect(snap.error, const PurchaseNetworkException());
    },
  );

  test('unusable offerings surface as PaywallUnavailableException', () async {
    final container = arrange(
      FakePurchasesRepository()
        ..onFetchOfferings = () async => const Offerings(<String, Offering>{}),
    );
    container.listen(paywallOfferingProvider, (_, _) {});
    await pumpEventQueue();

    final snap = container.read(paywallOfferingProvider);
    expect(snap.hasError, isTrue);
    expect(snap.error, const PaywallUnavailableException());
  });

  test(
    'a foreign error escaping the repository is mapped to the taxonomy',
    () async {
      final container = arrange(
        FakePurchasesRepository()
          ..onFetchOfferings = () async => throw const FormatException('x'),
      );
      container.listen(paywallOfferingProvider, (_, _) {});
      await pumpEventQueue();

      final snap = container.read(paywallOfferingProvider);
      expect(snap.hasError, isTrue);
      expect(snap.error, isA<PurchaseUnknownException>());
    },
  );
}
