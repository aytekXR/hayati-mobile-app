import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/privacy_lock/domain/pin_hasher.dart';

void main() {
  group('generateSalt', () {
    test('is 128 bits of base64 entropy', () {
      final salt = generateSalt();
      expect(base64Decode(salt), hasLength(16));
    });

    test('is distinct across calls (per-device random, never a constant)', () {
      final salts = List.generate(32, (_) => generateSalt()).toSet();
      expect(salts, hasLength(32));
    });
  });

  group('hashPin', () {
    test('round-trips: the same pin + salt yields the same digest', () {
      final salt = generateSalt();
      expect(
        hashPin(pin: '123456', salt: salt),
        hashPin(pin: '123456', salt: salt),
      );
    });

    test('is a 256-bit digest and never contains the raw PIN', () {
      final salt = generateSalt();
      final hash = hashPin(pin: '123456', salt: salt);

      expect(base64Decode(hash), hasLength(32));
      expect(hash, isNot(contains('123456')));
    });

    test('a wrong PIN does not reproduce the hash', () {
      final salt = generateSalt();
      expect(
        hashPin(pin: '000000', salt: salt),
        isNot(hashPin(pin: '123456', salt: salt)),
      );
    });

    test('the same PIN under a different salt yields a different hash', () {
      expect(
        hashPin(pin: '123456', salt: generateSalt()),
        isNot(hashPin(pin: '123456', salt: generateSalt())),
      );
    });
  });

  group('constantTimeEquals', () {
    test('true for identical digests', () {
      final salt = generateSalt();
      final hash = hashPin(pin: '123456', salt: salt);
      expect(
        constantTimeEquals(hash, hashPin(pin: '123456', salt: salt)),
        isTrue,
      );
    });

    test('false for differing digests of equal length', () {
      final salt = generateSalt();
      expect(
        constantTimeEquals(
          hashPin(pin: '123456', salt: salt),
          hashPin(pin: '123457', salt: salt),
        ),
        isFalse,
      );
    });

    test('false on a length mismatch (and on non-base64 garbage)', () {
      final salt = generateSalt();
      final hash = hashPin(pin: '123456', salt: salt);

      expect(constantTimeEquals(hash, base64Encode([1, 2, 3])), isFalse);
      expect(constantTimeEquals(hash, ''), isFalse);
      expect(constantTimeEquals(hash, 'not base64 !!!'), isFalse);
      expect(constantTimeEquals('', ''), isTrue);
    });
  });

  test('kPinLength is the 6-digit iOS-passcode convention (ADR-018 D1)', () {
    expect(kPinLength, 6);
  });
}
