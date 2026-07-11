import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/state/entitlement_providers.dart';
import 'package:hayati_app/features/entitlements/presentation/state/pending_purchase.dart';

import '../../../../support/fake_entitlement_repository.dart';

void main() {
  const coupleId = 'couple-1';
  final now = DateTime.utc(2026, 7, 11, 12);

  ProviderContainer arrange(FakeEntitlementRepository mirrors) {
    final container = ProviderContainer(
      overrides: [
        entitlementRepositoryProvider.overrideWith((ref) => mirrors),
        soloClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(mirrors.dispose);
    return container;
  }

  bool readFlag(ProviderContainer container) =>
      container.read(pendingPurchaseProvider(coupleId: coupleId));

  test('is false initially', () {
    final container = arrange(FakeEntitlementRepository());
    container.listen(pendingPurchaseProvider(coupleId: coupleId), (_, _) {});

    expect(readFlag(container), isFalse);
  });

  test('mark() flips the flag to true', () {
    final container = arrange(FakeEntitlementRepository());
    container.listen(pendingPurchaseProvider(coupleId: coupleId), (_, _) {});

    container.read(pendingPurchaseProvider(coupleId: coupleId).notifier).mark();

    expect(readFlag(container), isTrue);
  });

  test('auto-clears when isPremium flips true from the mirror', () async {
    final mirrors = FakeEntitlementRepository();
    final container = arrange(mirrors);
    container.listen(pendingPurchaseProvider(coupleId: coupleId), (_, _) {});
    await pumpEventQueue();

    container.read(pendingPurchaseProvider(coupleId: coupleId).notifier).mark();
    expect(readFlag(container), isTrue);

    // The webhook writes the entitled mirror → isPremium flips → flag clears.
    mirrors.emit(
      coupleId,
      CoupleEntitlement(
        entitled: true,
        expiresAt: now.add(const Duration(days: 1)),
      ),
    );
    await pumpEventQueue();

    expect(container.read(isPremiumProvider(coupleId: coupleId)), isTrue);
    expect(readFlag(container), isFalse);
  });
}
