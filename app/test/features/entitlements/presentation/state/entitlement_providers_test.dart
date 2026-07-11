import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_data_exception.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/state/entitlement_providers.dart';

import '../../../../support/fake_entitlement_repository.dart';

void main() {
  const coupleId = 'couple-1';
  // The pinned clock every gating test reads — deterministic, never the host's.
  final now = DateTime.utc(2026, 7, 11, 12);

  ({ProviderContainer container, FakeEntitlementRepository mirrors}) arrange({
    FakeEntitlementRepository? mirrors,
  }) {
    final repo = mirrors ?? FakeEntitlementRepository();
    final container = ProviderContainer(
      overrides: [
        entitlementRepositoryProvider.overrideWith((ref) => repo),
        soloClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);
    return (container: container, mirrors: repo);
  }

  // Keeps the derivation's stream dependency warm so it settles past loading
  // and recomputes on each emission (mirrors paired_providers_test).
  void keepPremiumAlive(ProviderContainer container) =>
      container.listen(isPremiumProvider(coupleId: coupleId), (_, _) {});

  bool readPremium(ProviderContainer container) =>
      container.read(isPremiumProvider(coupleId: coupleId));

  group('entitlementStream', () {
    test(
      'yields null while the mirror doc is absent (the free tier)',
      () async {
        final env = arrange();
        // Hold the stream open — a bare `.future` read would auto-dispose the
        // provider mid-load before the fake's first (null) emission arrives.
        env.container.listen(entitlementStreamProvider(coupleId), (_, _) {});

        expect(
          await env.container.read(entitlementStreamProvider(coupleId).future),
          isNull,
        );
      },
    );

    test('yields the mirror value once the doc exists', () async {
      final entitlement = CoupleEntitlement(
        entitled: true,
        productId: 'premium_monthly',
        expiresAt: DateTime.utc(2026, 8, 1),
        willRenew: true,
      );
      final env = arrange(
        mirrors: FakeEntitlementRepository(
          initialMirrors: {coupleId: entitlement},
        ),
      );
      env.container.listen(entitlementStreamProvider(coupleId), (_, _) {});
      await pumpEventQueue();

      expect(
        env.container.read(entitlementStreamProvider(coupleId)).value,
        entitlement,
      );
    });

    test('an emitError surfaces as an AsyncError and is not retried', () async {
      final env = arrange();
      env.container.listen(entitlementStreamProvider(coupleId), (_, _) {});
      await pumpEventQueue();

      env.mirrors.emitError(
        coupleId,
        const EntitlementDataNetworkException(message: 'off'),
      );
      await pumpEventQueue();

      final snap = env.container.read(entitlementStreamProvider(coupleId));
      expect(snap.hasError, isTrue);
      expect(snap.error, const EntitlementDataNetworkException(message: 'off'));

      // _noRetry: the errored stream is terminal — a retry would re-listen and
      // replay the stored (null) mirror as data, flipping this off the error.
      await pumpEventQueue();
      expect(
        env.container.read(entitlementStreamProvider(coupleId)).hasError,
        isTrue,
      );
    });
  });

  group('isPremium — free until proven entitled', () {
    test('is false while the stream is still loading', () {
      final env = arrange();
      keepPremiumAlive(env.container);

      // No pump: the stream has not emitted, so the derivation sees loading.
      expect(
        env.container.read(entitlementStreamProvider(coupleId)).isLoading,
        isTrue,
      );
      expect(readPremium(env.container), isFalse);
    });

    test('is false for an absent mirror doc (the free tier)', () async {
      final env = arrange();
      keepPremiumAlive(env.container);
      await pumpEventQueue();

      expect(readPremium(env.container), isFalse);
    });

    test('is false for a present-but-un-entitled mirror', () async {
      final env = arrange(
        mirrors: FakeEntitlementRepository(
          initialMirrors: {coupleId: CoupleEntitlement.free},
        ),
      );
      keepPremiumAlive(env.container);
      await pumpEventQueue();

      expect(readPremium(env.container), isFalse);
    });

    test('is true for an entitled, unexpired mirror', () async {
      final env = arrange(
        mirrors: FakeEntitlementRepository(
          initialMirrors: {
            coupleId: CoupleEntitlement(
              entitled: true,
              expiresAt: now.add(const Duration(days: 1)),
            ),
          },
        ),
      );
      keepPremiumAlive(env.container);
      await pumpEventQueue();

      expect(readPremium(env.container), isTrue);
    });

    test(
      'is false for an entitled mirror whose expiry is past the clock',
      () async {
        // entitled:true with a past expiresAt is the delayed-EXPIRATION window
        // (ADR-013 Decision 5): entitled alone is never a grant, so the
        // future-check against the pinned clock downgrades it.
        final env = arrange(
          mirrors: FakeEntitlementRepository(
            initialMirrors: {
              coupleId: CoupleEntitlement(
                entitled: true,
                expiresAt: now.subtract(const Duration(minutes: 1)),
              ),
            },
          ),
        );
        keepPremiumAlive(env.container);
        await pumpEventQueue();

        expect(readPremium(env.container), isFalse);
      },
    );

    test(
      'is true for an entitled mirror with a null (non-expiring) expiry',
      () async {
        final env = arrange(
          mirrors: FakeEntitlementRepository(
            initialMirrors: {coupleId: const CoupleEntitlement(entitled: true)},
          ),
        );
        keepPremiumAlive(env.container);
        await pumpEventQueue();

        expect(readPremium(env.container), isTrue);
      },
    );

    test('is false when the stream latches an error (_noRetry)', () async {
      final env = arrange(
        mirrors: FakeEntitlementRepository(
          initialMirrors: {
            coupleId: CoupleEntitlement(
              entitled: true,
              expiresAt: now.add(const Duration(days: 1)),
            ),
          },
        ),
      );
      keepPremiumAlive(env.container);
      await pumpEventQueue();
      // Premium first, then a rules denial latches the stream on the error.
      expect(readPremium(env.container), isTrue);

      env.mirrors.emitError(
        coupleId,
        const EntitlementDataPermissionException(message: 'denied'),
      );
      await pumpEventQueue();

      expect(
        env.container.read(entitlementStreamProvider(coupleId)).hasError,
        isTrue,
      );
      expect(readPremium(env.container), isFalse);
    });

    test('downgrades live when the entitled mirror is replaced by the free '
        'state (expiry downgrades both)', () async {
      final env = arrange(
        mirrors: FakeEntitlementRepository(
          initialMirrors: {
            coupleId: CoupleEntitlement(
              entitled: true,
              expiresAt: now.add(const Duration(days: 1)),
            ),
          },
        ),
      );
      keepPremiumAlive(env.container);
      await pumpEventQueue();
      expect(readPremium(env.container), isTrue);

      env.mirrors.emit(coupleId, CoupleEntitlement.free);
      await pumpEventQueue();

      expect(readPremium(env.container), isFalse);
    });
  });
}
