import 'package:purchases_flutter/purchases_flutter.dart';

/// Real `purchases_flutter` model objects backing the paywall tests (ADR-014
/// Decision 5): the seam speaks the SDK's own types, so minting genuine
/// (const-constructible) objects here means M4.3's live wiring is a bootstrap
/// override, not a reshape. One TRY storefront fixture (prices verbatim, self
/// consistent) — storefront currency follows the store account, not the device
/// locale, so the same strings render in every locale cell.

const _context = PresentedOfferingContext('default', null, null);

const _annualProduct = StoreProduct(
  'rc_annual',
  'Hayati Premium, billed annually',
  'Hayati Premium (Annual)',
  899.99,
  '₺899,99',
  'TRY',
  // A self-consistent 7-day free trial: price == 0, period agrees with
  // (periodUnit, periodNumberOfUnits).
  introductoryPrice: IntroductoryPrice(0, '₺0,00', 'P7D', 1, PeriodUnit.day, 7),
  pricePerYear: 899.99,
  pricePerYearString: '₺899,99',
  pricePerMonth: 74.99,
  pricePerMonthString: '₺74,99',
  subscriptionPeriod: 'P1Y',
);

const _annualPackage = Package(
  'rc_annual',
  PackageType.annual,
  _annualProduct,
  _context,
);

const _monthlyProduct = StoreProduct(
  'rc_monthly',
  'Hayati Premium, billed monthly',
  'Hayati Premium (Monthly)',
  89.99,
  '₺89,99',
  'TRY',
  pricePerMonth: 89.99,
  pricePerMonthString: '₺89,99',
  subscriptionPeriod: 'P1M',
);

const _monthlyPackage = Package(
  'rc_monthly',
  PackageType.monthly,
  _monthlyProduct,
  _context,
);

const _offering = Offering(
  'default',
  'Hayati Premium',
  <String, Object>{},
  [_annualPackage, _monthlyPackage],
  annual: _annualPackage,
  monthly: _monthlyPackage,
);

const _offerings = Offerings(<String, Offering>{
  'default': _offering,
}, current: _offering);

/// The annual package: TRY `₺899,99`, `₺74,99`/month sub-label, 7-day trial.
Package anAnnualPackage() => _annualPackage;

/// The monthly package: TRY `₺89,99`, no trial.
Package aMonthlyPackage() => _monthlyPackage;

/// The F4-shaped offerings: a current `default` offering carrying annual +
/// monthly, both in the named slots and in `availablePackages`.
Offerings aMockedOfferings() => _offerings;

/// The smallest honest [CustomerInfo] for a purchase/restore return — no
/// entitlements (the mirror is the only unlocker; customerInfo is a hint).
CustomerInfo aCustomerInfo() => const CustomerInfo(
  EntitlementInfos(<String, EntitlementInfo>{}, <String, EntitlementInfo>{}),
  <String, String?>{},
  <String>[],
  <String>[],
  <StoreTransaction>[],
  '2026-07-11T00:00:00Z',
  'uid-1',
  <String, String?>{},
  '2026-07-11T00:00:00Z',
);
