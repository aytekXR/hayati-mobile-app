import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/data/purchases_failure_mapper.dart';
import 'package:hayati_app/features/entitlements/domain/purchase_exception.dart';

void main() {
  // PurchasesErrorCode indices (the SDK enum order): 1 cancelled, 2 store,
  // 3 not-allowed, 10 network, 20 payment-pending, 23 configuration,
  // 35 offline. 0 is unknownError (falls to the Unknown bucket).
  PlatformException coded(String code) => PlatformException(code: code);

  group('numeric-coded PlatformExceptions bucket by enum index', () {
    test('purchaseCancelledError → PurchaseCancelledException', () {
      expect(
        mapPurchasesFailure(coded('1')),
        const PurchaseCancelledException(),
      );
    });

    test(
      'networkError and offlineConnectionError → PurchaseNetworkException',
      () {
        expect(
          mapPurchasesFailure(coded('10')),
          const PurchaseNetworkException(),
        );
        expect(
          mapPurchasesFailure(coded('35')),
          const PurchaseNetworkException(),
        );
      },
    );

    test('store/billing codes → PurchaseStoreException', () {
      expect(mapPurchasesFailure(coded('2')), const PurchaseStoreException());
      expect(mapPurchasesFailure(coded('3')), const PurchaseStoreException());
      expect(mapPurchasesFailure(coded('20')), const PurchaseStoreException());
    });

    test('configurationError → PurchasesUnavailableException', () {
      expect(
        mapPurchasesFailure(coded('23')),
        const PurchasesUnavailableException(),
      );
    });

    test(
      'an unbucketed known code → PurchaseUnknownException with the code',
      () {
        final result = mapPurchasesFailure(coded('0'));
        expect(result, isA<PurchaseUnknownException>());
        expect((result as PurchaseUnknownException).code, '0');
      },
    );
  });

  group('the totality guard around a non-total SDK helper', () {
    test('a non-numeric code maps (never throws FormatException)', () {
      final result = mapPurchasesFailure(coded('channel-error'));
      expect(result, isA<PurchaseUnknownException>());
      expect((result as PurchaseUnknownException).code, 'channel-error');
    });

    test('a negative code maps (never throws RangeError)', () {
      final result = mapPurchasesFailure(coded('-1'));
      expect(result, isA<PurchaseUnknownException>());
      expect((result as PurchaseUnknownException).code, '-1');
    });

    test('an out-of-range code maps to Unknown', () {
      final result = mapPurchasesFailure(coded('9999'));
      expect(result, isA<PurchaseUnknownException>());
      expect((result as PurchaseUnknownException).code, '9999');
    });
  });

  group('non-PlatformException failures', () {
    test('MissingPluginException → PurchasesUnavailableException', () {
      expect(
        mapPurchasesFailure(MissingPluginException('no channel')),
        const PurchasesUnavailableException(),
      );
    });

    test('a random object → PurchaseUnknownException carrying its string', () {
      final result = mapPurchasesFailure(const FormatException('boom'));
      expect(result, isA<PurchaseUnknownException>());
      expect((result as PurchaseUnknownException).message, contains('boom'));
    });

    test('an already-typed PurchaseException passes through unchanged', () {
      const original = PurchaseNetworkException();
      expect(identical(mapPurchasesFailure(original), original), isTrue);
    });
  });
}
