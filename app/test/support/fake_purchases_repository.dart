import 'package:hayati_app/features/entitlements/domain/purchases_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases_fixtures.dart';

/// Hand-written fake backing the purchases-seam tests (M4.2, ADR-014 Decision
/// 5). Records an ordered [callLog] (the `logIn`-before-`purchase` contract
/// proof) and exposes behaviour knobs where a test needs a specific outcome;
/// the identity/buying calls carry safe canned defaults so a bare arrangement
/// still succeeds. No streams, so nothing to dispose.
class FakePurchasesRepository implements PurchasesRepository {
  /// Ordered record of calls: `logIn:<uid>`, `logOut`, `fetchOfferings`,
  /// `purchase:<packageId>`, `restore`.
  final List<String> callLog = [];

  /// Behaviour of the next [logIn]/[logOut] — default records and succeeds.
  /// Set to a throwing function to prove the identity sync contains failures.
  Future<void> Function(String appUserId)? onLogIn;
  Future<void> Function()? onLogOut;

  /// Behaviour of the next [fetchOfferings]/[purchase]/[restore] — defaults to
  /// the canonical fixtures ([aMockedOfferings]/[aCustomerInfo] success).
  Future<Offerings> Function()? onFetchOfferings;
  Future<CustomerInfo> Function(Package package)? onPurchase;
  Future<CustomerInfo> Function()? onRestore;

  @override
  Future<void> logIn(String appUserId) async {
    callLog.add('logIn:$appUserId');
    final handler = onLogIn;
    if (handler != null) await handler(appUserId);
  }

  @override
  Future<void> logOut() async {
    callLog.add('logOut');
    final handler = onLogOut;
    if (handler != null) await handler();
  }

  @override
  Future<Offerings> fetchOfferings() async {
    callLog.add('fetchOfferings');
    final handler = onFetchOfferings;
    if (handler != null) return handler();
    return aMockedOfferings();
  }

  @override
  Future<CustomerInfo> purchase(Package package) async {
    callLog.add('purchase:${package.identifier}');
    final handler = onPurchase;
    if (handler != null) return handler(package);
    return aCustomerInfo();
  }

  @override
  Future<CustomerInfo> restore() async {
    callLog.add('restore');
    final handler = onRestore;
    if (handler != null) return handler();
    return aCustomerInfo();
  }
}
