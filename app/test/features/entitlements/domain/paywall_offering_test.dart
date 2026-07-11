import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/domain/paywall_offering.dart';
import 'package:hayati_app/features/entitlements/domain/purchase_exception.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../support/purchases_fixtures.dart';

void main() {
  const context = PresentedOfferingContext('default', null, null);

  Package packageOf(
    StoreProduct product, {
    required PackageType type,
    required String id,
  }) => Package(id, type, product, context);

  StoreProduct productOf({
    String id = 'rc_x',
    String priceString = '₺89,99',
    IntroductoryPrice? introductoryPrice,
    SubscriptionOption? defaultOption,
    String? pricePerMonthString,
  }) => StoreProduct(
    id,
    'desc',
    'title',
    89.99,
    priceString,
    'TRY',
    introductoryPrice: introductoryPrice,
    defaultOption: defaultOption,
    pricePerMonthString: pricePerMonthString,
  );

  Offerings offeringsOf(
    List<Package> packages, {
    Package? annual,
    Package? monthly,
  }) {
    final offering = Offering(
      'default',
      'desc',
      const <String, Object>{},
      packages,
      annual: annual,
      monthly: monthly,
    );
    return Offerings(<String, Offering>{
      'default': offering,
    }, current: offering);
  }

  group('package order', () {
    test('promotes annual first, then monthly (the mocked F4 offering)', () {
      final result = derivePaywallOffering(aMockedOfferings());

      expect(result.packages.map((p) => p.packageType), [
        PackageType.annual,
        PackageType.monthly,
      ]);
    });

    test('dedups packages present in both the named slots and the list', () {
      // aMockedOfferings carries annual + monthly in the slots AND in
      // availablePackages — each must appear exactly once.
      final result = derivePaywallOffering(aMockedOfferings());

      expect(result.packages, hasLength(2));
    });

    test('with no annual slot the server order stands (no promotion)', () {
      // Monthly and annual are in the list in server order, but the annual
      // SLOT is unset — so no annual-first arrangement is applied.
      final offerings = offeringsOf([aMonthlyPackage(), anAnnualPackage()]);

      final result = derivePaywallOffering(offerings);

      expect(result.packages.map((p) => p.packageType), [
        PackageType.monthly,
        PackageType.annual,
      ]);
    });
  });

  group('trial detection', () {
    test('an introductoryPrice with price == 0 is a trial (count, unit)', () {
      final result = derivePaywallOffering(aMockedOfferings());

      final trial = result.packages.first.trial;
      expect(trial, isNotNull);
      expect(trial!.count, 7);
      expect(trial.unit, PeriodUnit.day);
    });

    test('a non-zero introductoryPrice is a discount, not a trial', () {
      final product = productOf(
        introductoryPrice: const IntroductoryPrice(
          50,
          '₺50,00',
          'P7D',
          1,
          PeriodUnit.day,
          7,
        ),
      );
      final offerings = offeringsOf([
        packageOf(product, type: PackageType.annual, id: 'rc_annual'),
      ], annual: packageOf(product, type: PackageType.annual, id: 'rc_annual'));

      expect(derivePaywallOffering(offerings).packages.first.trial, isNull);
    });

    test('falls back to a freePhase billing period when no intro price', () {
      const freePhase = PricingPhase(
        Period(PeriodUnit.day, 7, 'P7D'),
        RecurrenceMode.finiteRecurring,
        1,
        Price('₺0,00', 0, 'TRY'),
        OfferPaymentMode.freeTrial,
      );
      const option = SubscriptionOption(
        'monthly-base',
        'rc_monthly',
        'rc_monthly',
        <PricingPhase>[freePhase],
        <String>[],
        true,
        Period(PeriodUnit.month, 1, 'P1M'),
        false,
        null,
        freePhase,
        null,
        null,
        null,
      );
      final product = productOf(defaultOption: option);
      final offerings = offeringsOf([
        packageOf(product, type: PackageType.monthly, id: 'rc_monthly'),
      ]);

      final trial = derivePaywallOffering(offerings).packages.first.trial;
      expect(trial, isNotNull);
      expect(trial!.count, 7);
      expect(trial.unit, PeriodUnit.day);
    });

    test('a freePhase without a billing period is a unit-less marker', () {
      const freePhase = PricingPhase(
        null,
        RecurrenceMode.finiteRecurring,
        1,
        Price('₺0,00', 0, 'TRY'),
        OfferPaymentMode.freeTrial,
      );
      const option = SubscriptionOption(
        'monthly-base',
        'rc_monthly',
        'rc_monthly',
        <PricingPhase>[freePhase],
        <String>[],
        true,
        null,
        false,
        null,
        freePhase,
        null,
        null,
        null,
      );
      final product = productOf(defaultOption: option);
      final offerings = offeringsOf([
        packageOf(product, type: PackageType.monthly, id: 'rc_monthly'),
      ]);

      final trial = derivePaywallOffering(offerings).packages.first.trial;
      expect(trial, isNotNull);
      expect(trial!.count, isNull);
      expect(trial.unit, isNull);
    });
  });

  group('price sub-label', () {
    test('annual carries pricePerMonthString verbatim; monthly does not', () {
      final result = derivePaywallOffering(aMockedOfferings());

      expect(result.packages[0].pricePerMonthString, '₺74,99');
      expect(result.packages[0].priceString, '₺899,99');
      expect(result.packages[1].pricePerMonthString, isNull);
      expect(result.packages[1].priceString, '₺89,99');
    });
  });

  group('unusable offerings', () {
    test('throws PaywallUnavailableException when there is no current', () {
      const offerings = Offerings(<String, Offering>{});

      expect(
        () => derivePaywallOffering(offerings),
        throwsA(const PaywallUnavailableException()),
      );
    });

    test('throws PaywallUnavailableException on an empty package list', () {
      final offerings = offeringsOf(const <Package>[]);

      expect(
        () => derivePaywallOffering(offerings),
        throwsA(const PaywallUnavailableException()),
      );
    });
  });
}
