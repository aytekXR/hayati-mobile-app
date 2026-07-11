import 'package:purchases_flutter/purchases_flutter.dart';

/// Seam over `purchases_flutter` (M4.2, ADR-014 Decision 1). The SDK drives
/// platform channels — untestable in the `flutter test` VM (the M2.2
/// `cloud_functions` precedent) — so every test runs against a fake and the
/// real adapter (`RcPurchasesRepository`) is exercised on-device at M4.3.
///
/// The seam speaks the SDK's own model types ([Offerings], [Package],
/// [CustomerInfo]): the fake mints real SDK objects, so the live wiring lands
/// as a bootstrap override rather than a reshape. The paywall never renders
/// these raw — it renders the `derivePaywallOffering` display model, keeping
/// the SDK surface contained to this seam plus one pure derivation.
abstract interface class PurchasesRepository {
  /// Binds the RC identity to the Firebase uid — load-bearing (ADR-013
  /// Decision 3): it must precede any purchase or the webhook resolves no
  /// couple and the mirror stays free.
  Future<void> logIn(String appUserId);

  /// Resets the RC identity to anonymous on sign-out.
  Future<void> logOut();

  /// The store's current offerings; the display model is derived from these.
  Future<Offerings> fetchOfferings();

  /// Buys [package] (the adapter builds `PurchaseParams.package(package)`) and
  /// returns the post-purchase [CustomerInfo] — a hint, never truth (ADR-013):
  /// no UI flips entitled from it; the `subscriptions/{coupleId}` mirror is the
  /// only unlocker.
  Future<CustomerInfo> purchase(Package package);

  /// Restores prior purchases, returning the resulting [CustomerInfo] (same
  /// hint-not-truth contract as [purchase]).
  Future<CustomerInfo> restore();
}
