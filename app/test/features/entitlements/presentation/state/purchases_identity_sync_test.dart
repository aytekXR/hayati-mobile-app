import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/state/paywall_purchase_controller.dart';
import 'package:hayati_app/features/entitlements/presentation/state/purchases_identity_sync.dart';

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_entitlement_repository.dart';
import '../../../../support/fake_purchases_repository.dart';
import '../../../../support/purchases_fixtures.dart';

void main() {
  const uid = 'uid-1';
  const user = AuthUser(uid: uid);

  ProviderContainer withPurchases(
    FakeAuthRepository auth,
    FakePurchasesRepository purchases,
  ) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => auth),
        purchasesRepositoryProvider.overrideWith((ref) => purchases),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    return container;
  }

  test('warm start: a restored signed-in session logs logIn once with no auth '
      'event', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final purchases = FakePurchasesRepository();
    final container = withPurchases(auth, purchases);

    // Activate the sync — no emit, the session is already signed-in.
    container.read(purchasesIdentitySyncProvider);
    await pumpEventQueue();

    expect(purchases.callLog, ['logIn:$uid']);
  });

  test('cold start signed-out: no calls and the purchases provider is never '
      'resolved (lazy read)', () async {
    final auth = FakeAuthRepository();
    // Deliberately NO purchasesRepositoryProvider override: it is
    // throw-until-overridden, so any resolution would surface a StateError.
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) => auth)],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);

    expect(
      () => container.read(purchasesIdentitySyncProvider),
      returnsNormally,
    );
    await pumpEventQueue();
  });

  test('a sign-in transition logs logIn once', () async {
    final auth = FakeAuthRepository();
    final purchases = FakePurchasesRepository();
    final container = withPurchases(auth, purchases);
    container.read(purchasesIdentitySyncProvider);
    await pumpEventQueue();
    expect(purchases.callLog, isEmpty);

    auth.emit(user);
    await pumpEventQueue();

    expect(purchases.callLog, ['logIn:$uid']);
  });

  test('re-emitting the same uid still logs logIn once', () async {
    final auth = FakeAuthRepository();
    final purchases = FakePurchasesRepository();
    final container = withPurchases(auth, purchases);
    container.read(purchasesIdentitySyncProvider);

    auth.emit(user);
    await pumpEventQueue();
    // Same uid, different profile fields → a real state change that fires the
    // listener, exercising the sync's own dedupe (not just AuthState equality).
    auth.emit(const AuthUser(uid: uid, displayName: 'changed'));
    await pumpEventQueue();

    expect(purchases.callLog.where((e) => e.startsWith('logIn')), hasLength(1));
  });

  test('a sign-in → sign-out transition logs logOut exactly once', () async {
    final auth = FakeAuthRepository();
    final purchases = FakePurchasesRepository();
    final container = withPurchases(auth, purchases);
    container.read(purchasesIdentitySyncProvider);

    auth.emit(user);
    await pumpEventQueue();
    auth.emit(null);
    await pumpEventQueue();

    expect(purchases.callLog, ['logIn:$uid', 'logOut']);
  });

  test('an initial signed-out lifecycle never calls logOut', () async {
    final auth = FakeAuthRepository();
    final purchases = FakePurchasesRepository();
    final container = withPurchases(auth, purchases);

    container.read(purchasesIdentitySyncProvider);
    await pumpEventQueue();

    expect(purchases.callLog, isEmpty);
  });

  test('a logIn failure is contained (no unhandled error)', () async {
    final auth = FakeAuthRepository(initialUser: user);
    final purchases = FakePurchasesRepository()
      ..onLogIn = (_) async => throw StateError('boom');
    final container = withPurchases(auth, purchases);

    container.read(purchasesIdentitySyncProvider);
    await pumpEventQueue();

    // The attempt is recorded and the throw is swallowed — the test reaching
    // here without an unhandled async error is the containment proof.
    expect(purchases.callLog, ['logIn:$uid']);
  });

  test(
    'logs logIn before purchase (the identity → purchase order contract)',
    () async {
      const coupleId = 'couple-1';
      final auth = FakeAuthRepository();
      final purchases = FakePurchasesRepository();
      final entitlements = FakeEntitlementRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => auth),
          purchasesRepositoryProvider.overrideWith((ref) => purchases),
          entitlementRepositoryProvider.overrideWith((ref) => entitlements),
          soloClockProvider.overrideWith(
            (ref) =>
                () => DateTime.utc(2026, 7, 11, 12),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.dispose);
      addTearDown(entitlements.dispose);

      // The shared fake sees the identity sync and the purchase drive.
      container.read(purchasesIdentitySyncProvider);
      auth.emit(user);
      await pumpEventQueue();

      await container
          .read(paywallPurchaseControllerProvider(coupleId: coupleId).notifier)
          .purchase(anAnnualPackage());
      await pumpEventQueue();

      final logInIndex = purchases.callLog.indexOf('logIn:$uid');
      final purchaseIndex = purchases.callLog.indexOf('purchase:rc_annual');
      expect(logInIndex, isNonNegative);
      expect(purchaseIndex, greaterThan(logInIndex));
    },
  );
}
