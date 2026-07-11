import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/data/couple_entitlement_dto.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';

/// A wire-shaped `subscriptions/{coupleId}` document; tests mutate copies of it
/// to hit each loud branch (same idiom as couple_dto_test).
Map<String, dynamic> validMirror() => {
  'entitled': true,
  'productId': 'premium_monthly',
  'periodType': 'NORMAL',
  'expiresAtMs': 1785500400000,
  'willRenew': true,
  'store': 'APP_STORE',
  'environment': 'SANDBOX',
};

void main() {
  group('coupleEntitlementFromMap', () {
    test('maps a wire document into the domain summary', () {
      final entitlement = coupleEntitlementFromMap(validMirror());

      expect(entitlement.entitled, isTrue);
      expect(entitlement.productId, 'premium_monthly');
      expect(entitlement.periodType, 'NORMAL');
      expect(
        entitlement.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1785500400000, isUtc: true),
      );
      expect(entitlement.willRenew, isTrue);
      expect(entitlement.store, 'APP_STORE');
      expect(entitlement.environment, 'SANDBOX');
    });

    test('crosses expiresAtMs as a UTC instant', () {
      final entitlement = coupleEntitlementFromMap(
        validMirror()..['expiresAtMs'] = 0,
      );

      // DateTime equality is timezone-aware, so the isUtc flag is load-bearing:
      // the mapper must produce a UTC instant (a couple-local reader converts).
      expect(
        entitlement.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(entitlement.expiresAt!.isUtc, isTrue);
    });

    group('absent fields fall back to the free/zero-state', () {
      test('an empty document reads as the free tier', () {
        // A present-but-fieldless doc is drift; the safe reading is free until
        // the webhook proves otherwise, never a throw.
        expect(coupleEntitlementFromMap(const {}), CoupleEntitlement.free);
      });

      test('entitled:false with no other fields equals free', () {
        expect(
          coupleEntitlementFromMap(const {'entitled': false}),
          CoupleEntitlement.free,
        );
      });

      test('an absent expiresAtMs maps to a null (non-expiring) expiry', () {
        final entitlement = coupleEntitlementFromMap(
          validMirror()..remove('expiresAtMs'),
        );

        expect(entitlement.expiresAt, isNull);
      });

      test('absent willRenew defaults to false', () {
        final entitlement = coupleEntitlementFromMap(
          validMirror()..remove('willRenew'),
        );

        expect(entitlement.willRenew, isFalse);
      });
    });

    group('a present-but-malformed field fails loudly', () {
      test('a non-bool entitled throws', () {
        expect(
          () => coupleEntitlementFromMap(validMirror()..['entitled'] = 'yes'),
          throwsFormatException,
        );
      });

      test('a non-bool willRenew throws', () {
        expect(
          () => coupleEntitlementFromMap(validMirror()..['willRenew'] = 1),
          throwsFormatException,
        );
      });

      test('a non-string productId throws', () {
        expect(
          () => coupleEntitlementFromMap(validMirror()..['productId'] = 42),
          throwsFormatException,
        );
      });

      test('a non-string periodType throws', () {
        expect(
          () => coupleEntitlementFromMap(validMirror()..['periodType'] = 42),
          throwsFormatException,
        );
      });

      test('a non-string store throws', () {
        expect(
          () => coupleEntitlementFromMap(validMirror()..['store'] = 42),
          throwsFormatException,
        );
      });

      test('a non-string environment throws', () {
        expect(
          () => coupleEntitlementFromMap(validMirror()..['environment'] = 42),
          throwsFormatException,
        );
      });

      test('a non-int expiresAtMs throws (a String, a double, ...)', () {
        // The missed/wrong-conversion guard: a null expiresAtMs is the
        // non-expiring sentinel, so any non-int must throw rather than silently
        // void the expiry (ADR-013 — a null expiry never means "malformed").
        for (final bad in <Object>['soon', 1.5]) {
          expect(
            () =>
                coupleEntitlementFromMap(validMirror()..['expiresAtMs'] = bad),
            throwsFormatException,
            reason: 'expiresAtMs=$bad must fail loudly',
          );
        }
      });
    });
  });
}
