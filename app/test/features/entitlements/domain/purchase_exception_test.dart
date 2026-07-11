import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/domain/purchase_exception.dart';

void main() {
  group('field-less exceptions — value equality by type', () {
    test('each equals another instance of itself', () {
      expect(
        const PurchaseCancelledException(),
        const PurchaseCancelledException(),
      );
      expect(
        const PurchasesUnavailableException(),
        const PurchasesUnavailableException(),
      );
      expect(
        const PurchaseNotIdentifiedException(),
        const PurchaseNotIdentifiedException(),
      );
      expect(
        const PurchaseNetworkException(),
        const PurchaseNetworkException(),
      );
      expect(const PurchaseStoreException(), const PurchaseStoreException());
      expect(
        const PaywallUnavailableException(),
        const PaywallUnavailableException(),
      );
    });

    test('distinct types are not equal', () {
      expect(
        const PurchaseNetworkException(),
        isNot(const PurchaseStoreException()),
      );
      expect(
        const PurchasesUnavailableException(),
        isNot(const PaywallUnavailableException()),
      );
    });

    test('hashCode is stable per type', () {
      expect(
        const PurchaseCancelledException().hashCode,
        const PurchaseCancelledException().hashCode,
      );
      expect(
        const PurchaseNetworkException().hashCode,
        isNot(const PurchaseStoreException().hashCode),
      );
    });

    test('toString names the type', () {
      expect(
        const PurchaseCancelledException().toString(),
        'PurchaseCancelledException()',
      );
      expect(
        const PaywallUnavailableException().toString(),
        'PaywallUnavailableException()',
      );
    });
  });

  group('PurchaseUnknownException — value equality by code + message', () {
    test('equal for the same code and message', () {
      expect(
        const PurchaseUnknownException(code: 'channel-error', message: 'x'),
        const PurchaseUnknownException(code: 'channel-error', message: 'x'),
      );
    });

    test('differs on code or message', () {
      expect(
        const PurchaseUnknownException(code: 'a'),
        isNot(const PurchaseUnknownException(code: 'b')),
      );
      expect(
        const PurchaseUnknownException(code: 'a', message: 'x'),
        isNot(const PurchaseUnknownException(code: 'a', message: 'y')),
      );
    });

    test('toString carries code and message', () {
      expect(
        const PurchaseUnknownException(code: '-1', message: 'oops').toString(),
        'PurchaseUnknownException(code: -1, message: oops)',
      );
    });
  });
}
