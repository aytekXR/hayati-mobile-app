import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/purchase_exception.dart';
import '../domain/purchases_repository.dart';
import 'purchases_failure_mapper.dart';

/// RevenueCat iOS public SDK key, injected via
/// `--dart-define=REVENUECAT_IOS_API_KEY=...` (empty by default — no RC account
/// yet, operator item 0). Public SDK keys are identifiers, not secrets, but
/// with nothing to commit the dart-define seam (the `APP_CHECK_DEBUG_TOKEN`
/// pattern) carries it; when the account exists a committed-per-flavor const
/// can be revisited (ADR-014 Decision 2).
const String kRevenueCatIosApiKey = String.fromEnvironment(
  'REVENUECAT_IOS_API_KEY',
);

/// Thin `purchases_flutter` adapter (ADR-014 Decisions 1 & 2): forwards onto the
/// `Purchases.*` statics, mapping every failure through the taxonomy. Deliberately
/// NOT unit-tested — the statics are channel-backed and it holds no logic beyond
/// guards and mapping; its correctness is the M4.3 on-device smoke (the M2.2
/// precedent). Fail-closed when unconfigured: `logIn`/`logOut` no-op silently
/// (auth flows must never crash on a box without the key) while the buying
/// methods throw [PurchasesUnavailableException] loudly.
class RcPurchasesRepository implements PurchasesRepository {
  static bool _configured = false;

  /// Configures RevenueCat at bootstrap when [kRevenueCatIosApiKey] is present;
  /// a no-op (leaving the adapter unconfigured) when the key is empty.
  static Future<void> configureIfKeyed() async {
    if (kRevenueCatIosApiKey.isEmpty) return;
    await Purchases.configure(PurchasesConfiguration(kRevenueCatIosApiKey));
    _configured = true;
  }

  @override
  Future<void> logIn(String appUserId) async {
    if (!_configured) {
      debugPrint(
        'RcPurchasesRepository.logIn skipped: RevenueCat unconfigured',
      );
      return;
    }
    try {
      await Purchases.logIn(appUserId);
    } catch (failure) {
      throw mapPurchasesFailure(failure);
    }
  }

  @override
  Future<void> logOut() async {
    if (!_configured) {
      debugPrint(
        'RcPurchasesRepository.logOut skipped: RevenueCat unconfigured',
      );
      return;
    }
    try {
      await Purchases.logOut();
    } catch (failure) {
      throw mapPurchasesFailure(failure);
    }
  }

  @override
  Future<Offerings> fetchOfferings() async {
    if (!_configured) throw const PurchasesUnavailableException();
    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (failure) {
      throw mapPurchasesFailure(failure);
    }
  }

  @override
  Future<CustomerInfo> purchase(Package package) async {
    if (!_configured) throw const PurchasesUnavailableException();
    try {
      // The identity guard (ADR-013 Decision 3): an anonymous customer cannot
      // reach the store, so the webhook can always resolve the couple. The
      // deliberate throw passes through the mapper unchanged.
      if (await Purchases.isAnonymous) {
        throw const PurchaseNotIdentifiedException();
      }
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo;
    } catch (failure) {
      throw mapPurchasesFailure(failure);
    }
  }

  @override
  Future<CustomerInfo> restore() async {
    if (!_configured) throw const PurchasesUnavailableException();
    try {
      if (await Purchases.isAnonymous) {
        throw const PurchaseNotIdentifiedException();
      }
      final info = await Purchases.restorePurchases();
      return info;
    } catch (failure) {
      throw mapPurchasesFailure(failure);
    }
  }
}
