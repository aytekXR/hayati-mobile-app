import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchase_exception.dart';

/// A free-trial descriptor derived from a package's store data (ADR-014
/// Decision 3). [count]/[unit] carry the period when it is cleanly derivable
/// (iOS `introductoryPrice`, or an Android `freePhase` with a billing period),
/// and are both null for a "trial present, period unknown" marker — an honest
/// fallback the copy renders as a generic "free trial included" line. A null
/// [PaywallTrial] on a package means no trial at all.
class PaywallTrial {
  const PaywallTrial({this.count, this.unit});

  final int? count;
  final PeriodUnit? unit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywallTrial && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'PaywallTrial(count: $count, unit: $unit)';
}

/// One purchasable row on the paywall, derived from a [Package] (ADR-014
/// Decision 3). The raw [package] rides along so the CTA can drive
/// `PaywallPurchaseController.purchase(package)` without re-resolving it; all
/// display fields are verbatim from the store (never re-formatted).
class PaywallPackage {
  const PaywallPackage({
    required this.package,
    required this.packageType,
    required this.priceString,
    this.pricePerMonthString,
    this.trial,
  });

  /// The SDK package to purchase — carried, never rendered raw.
  final Package package;

  final PackageType packageType;

  /// Store-localized price, verbatim (TRY/SAR/USD is the store's job).
  final String priceString;

  /// Store-computed "≈ x/month" sub-label, verbatim — set only for the annual
  /// package, and null when the SDK did not compute it.
  final String? pricePerMonthString;

  /// The free trial this package carries, or null for none.
  final PaywallTrial? trial;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywallPackage &&
          other.package == package &&
          other.packageType == packageType &&
          other.priceString == priceString &&
          other.pricePerMonthString == pricePerMonthString &&
          other.trial == trial;

  @override
  int get hashCode => Object.hash(
    package,
    packageType,
    priceString,
    pricePerMonthString,
    trial,
  );

  @override
  String toString() =>
      'PaywallPackage(packageType: $packageType, priceString: $priceString, '
      'pricePerMonthString: $pricePerMonthString, trial: $trial)';
}

/// The paywall's pure display model — the annual-first ordered [packages]
/// (ADR-014 Decision 3). The SDK surface stays contained to the derivation
/// below; the screen renders only this.
class PaywallOffering {
  const PaywallOffering({required this.packages});

  final List<PaywallPackage> packages;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaywallOffering &&
          other.packages.length == packages.length &&
          _samePackages(other.packages);

  bool _samePackages(List<PaywallPackage> otherPackages) {
    for (var i = 0; i < packages.length; i++) {
      if (packages[i] != otherPackages[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(packages);

  @override
  String toString() => 'PaywallOffering(packages: $packages)';
}

/// Derives the paywall display model from the store's [offerings] (ADR-014
/// Decision 3, heavily unit-tested).
///
/// Order: annual first (`current.annual`), then monthly, then the remaining
/// `availablePackages` in server order, deduped by identifier. With no annual
/// package the server order stands untouched (the dashboard decides).
///
/// Throws [PaywallUnavailableException] when there is no current offering or it
/// carries no packages — the honest error state, never an empty sheet.
PaywallOffering derivePaywallOffering(Offerings offerings) {
  final current = offerings.current;
  if (current == null || current.availablePackages.isEmpty) {
    throw const PaywallUnavailableException();
  }
  return PaywallOffering(
    packages: _orderPackages(current).map(_toPaywallPackage).toList(),
  );
}

/// Annual-first ordering with identifier dedup; a missing annual slot leaves
/// the server order untouched (no annual-first arrangement to apply).
List<Package> _orderPackages(Offering offering) {
  if (offering.annual == null) return offering.availablePackages;
  final ordered = <Package>[];
  final seen = <String>{};
  void add(Package? package) {
    if (package != null && seen.add(package.identifier)) ordered.add(package);
  }

  add(offering.annual);
  add(offering.monthly);
  for (final package in offering.availablePackages) {
    add(package);
  }
  return ordered;
}

PaywallPackage _toPaywallPackage(Package package) {
  final product = package.storeProduct;
  return PaywallPackage(
    package: package,
    packageType: package.packageType,
    priceString: product.priceString,
    pricePerMonthString: package.packageType == PackageType.annual
        ? product.pricePerMonthString
        : null,
    trial: _detectTrial(product),
  );
}

/// Trial detection (ADR-014 Decision 3): iOS surfaces a free trial as an
/// `introductoryPrice` with `price == 0` (a non-zero intro price is a discount,
/// never a trial). Failing that, an Android/cross-store `freePhase` marks a
/// trial (mapped for M6.5 completeness) — its period is read from the
/// `billingPeriod` when present, else surfaced as a unit-less marker.
PaywallTrial? _detectTrial(StoreProduct product) {
  final intro = product.introductoryPrice;
  if (intro != null && intro.price == 0) {
    return PaywallTrial(
      count: intro.periodNumberOfUnits,
      unit: intro.periodUnit,
    );
  }
  final freePhase = product.defaultOption?.freePhase;
  if (freePhase != null) {
    final period = freePhase.billingPeriod;
    if (period != null) {
      return PaywallTrial(count: period.value, unit: period.unit);
    }
    return const PaywallTrial();
  }
  return null;
}
