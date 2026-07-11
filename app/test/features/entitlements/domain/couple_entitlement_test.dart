import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';

void main() {
  group('CoupleEntitlement', () {
    final expiresAt = DateTime.utc(2026, 8, 1);

    test('free is the zero-state (un-entitled, everything null/false)', () {
      expect(CoupleEntitlement.free.entitled, isFalse);
      expect(CoupleEntitlement.free.productId, isNull);
      expect(CoupleEntitlement.free.periodType, isNull);
      expect(CoupleEntitlement.free.expiresAt, isNull);
      expect(CoupleEntitlement.free.willRenew, isFalse);
      expect(CoupleEntitlement.free.store, isNull);
      expect(CoupleEntitlement.free.environment, isNull);
    });

    // Absence == an explicit un-entitled doc (both the free tier) is proven at
    // the mapper level in couple_entitlement_dto_test — a present entitled:false
    // doc with no other fields is canonically CoupleEntitlement.free.

    test('value equality is field-based', () {
      final entitlement = CoupleEntitlement(
        entitled: true,
        productId: 'premium_monthly',
        periodType: 'NORMAL',
        expiresAt: expiresAt,
        willRenew: true,
        store: 'APP_STORE',
        environment: 'SANDBOX',
      );

      expect(
        entitlement,
        CoupleEntitlement(
          entitled: true,
          productId: 'premium_monthly',
          periodType: 'NORMAL',
          expiresAt: expiresAt,
          willRenew: true,
          store: 'APP_STORE',
          environment: 'SANDBOX',
        ),
      );
      expect(
        entitlement.hashCode,
        CoupleEntitlement(
          entitled: true,
          productId: 'premium_monthly',
          periodType: 'NORMAL',
          expiresAt: expiresAt,
          willRenew: true,
          store: 'APP_STORE',
          environment: 'SANDBOX',
        ).hashCode,
      );
    });

    test('each field participates in identity', () {
      final base = CoupleEntitlement(
        entitled: true,
        productId: 'premium_monthly',
        periodType: 'NORMAL',
        expiresAt: expiresAt,
        willRenew: true,
        store: 'APP_STORE',
        environment: 'SANDBOX',
      );

      expect(base, isNot(CoupleEntitlement.free));
      expect(
        base,
        isNot(
          CoupleEntitlement(
            entitled: true,
            productId: 'premium_yearly',
            periodType: 'NORMAL',
            expiresAt: expiresAt,
            willRenew: true,
            store: 'APP_STORE',
            environment: 'SANDBOX',
          ),
        ),
      );
      expect(
        base,
        isNot(
          CoupleEntitlement(
            entitled: true,
            productId: 'premium_monthly',
            periodType: 'NORMAL',
            expiresAt: DateTime.utc(2026, 9, 1),
            willRenew: true,
            store: 'APP_STORE',
            environment: 'SANDBOX',
          ),
        ),
      );
      expect(
        base,
        isNot(
          CoupleEntitlement(
            entitled: true,
            productId: 'premium_monthly',
            periodType: 'NORMAL',
            expiresAt: expiresAt,
            willRenew: false,
            store: 'APP_STORE',
            environment: 'SANDBOX',
          ),
        ),
      );
    });

    test('toString names every summary field for diagnostics', () {
      final entitlement = CoupleEntitlement(
        entitled: true,
        productId: 'premium_monthly',
        periodType: 'NORMAL',
        expiresAt: expiresAt,
        willRenew: true,
        store: 'APP_STORE',
        environment: 'SANDBOX',
      );

      final text = entitlement.toString();
      expect(text, contains('entitled: true'));
      expect(text, contains('premium_monthly'));
      expect(text, contains('NORMAL'));
      expect(text, contains('willRenew: true'));
      expect(text, contains('APP_STORE'));
      expect(text, contains('SANDBOX'));
    });
  });
}
