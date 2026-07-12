import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';

/// A record whose secret material is recognisable in a `toString()` haystack.
const _salt = 'U0FMVFNBTFRTQUxUU0FMVA==';
const _hash = 'SEFTSEhBU0hIQVNISEFTSEhBU0hIQVNISEFTSA==';
const _enrollment = 'RU5ST0xMTUVOVFNUQVRF';

PinLockRecord _aRecord() => const PinLockRecord(
  salt: _salt,
  pinHash: _hash,
  biometricEnabled: true,
  biometricEnrollmentState: _enrollment,
  wrongCount: 3,
  lockoutUntilMs: 1770000000000,
);

void main() {
  group('PinLockRecord JSON', () {
    test('round-trips through toJson/fromJson', () {
      final record = _aRecord();
      expect(PinLockRecord.fromJson(record.toJson()), record);
    });

    test('round-trips through encode/decode (the string the store persists)', () {
      final record = _aRecord();
      expect(PinLockRecord.decode(record.encode()), record);
    });

    test('carries the current version', () {
      expect(_aRecord().toJson()['version'], kPinLockRecordVersion);
      expect(kPinLockRecordVersion, 1);
    });

    test('an UNKNOWN version deserialises to null (treated as absent — D2)', () {
      final json = _aRecord().toJson()..['version'] = 2;
      expect(PinLockRecord.fromJson(json), isNull);
    });

    test('an ABSENT version deserialises to null', () {
      final json = _aRecord().toJson()..remove('version');
      expect(PinLockRecord.fromJson(json), isNull);
    });

    test('malformed / wrong-typed fields deserialise to null, never throw', () {
      expect(PinLockRecord.fromJson(_aRecord().toJson()..['salt'] = 7), isNull);
      expect(
        PinLockRecord.fromJson(_aRecord().toJson()..remove('pinHash')),
        isNull,
      );
      expect(
        PinLockRecord.fromJson(_aRecord().toJson()..['wrongCount'] = 'three'),
        isNull,
      );
      expect(
        PinLockRecord.fromJson(_aRecord().toJson()..['biometricEnabled'] = 1),
        isNull,
      );
      expect(
        PinLockRecord.fromJson(
          _aRecord().toJson()..['biometricEnrollmentState'] = 42,
        ),
        isNull,
      );
      expect(
        PinLockRecord.fromJson(_aRecord().toJson()..['lockoutUntilMs'] = 'soon'),
        isNull,
      );
      expect(PinLockRecord.fromJson(const <String, dynamic>{}), isNull);
    });

    test('a null lockout / enrollment survives the round trip', () {
      const record = PinLockRecord(
        salt: _salt,
        pinHash: _hash,
        biometricEnabled: false,
        wrongCount: 0,
      );
      expect(PinLockRecord.decode(record.encode()), record);
      expect(record.biometricEnrollmentState, isNull);
      expect(record.lockoutUntilMs, isNull);
    });

    test('decode returns null on garbage, a JSON non-object, or empty', () {
      expect(PinLockRecord.decode('{not json'), isNull);
      expect(PinLockRecord.decode('[]'), isNull);
      expect(PinLockRecord.decode('"hello"'), isNull);
      expect(PinLockRecord.decode(''), isNull);
    });
  });

  group('PinLockRecord value semantics', () {
    test('equal records are ==, differing records are not', () {
      expect(_aRecord(), _aRecord());
      expect(_aRecord().hashCode, _aRecord().hashCode);
      expect(_aRecord(), isNot(_aRecord().copyWith(wrongCount: 4)));
    });

    test('copyWith can null out the lockout and the enrollment state', () {
      final cleared = _aRecord().copyWith(
        biometricEnabled: false,
        biometricEnrollmentState: null,
        lockoutUntilMs: null,
      );
      expect(cleared.biometricEnrollmentState, isNull);
      expect(cleared.lockoutUntilMs, isNull);
      expect(cleared.salt, _salt, reason: 'untouched fields are preserved');
    });
  });

  group('the no-content rule (arch §8 / ADR-018 D2)', () {
    test('toString renders PRESENCE only — no salt, hash, or enrollment bytes', () {
      final rendered = _aRecord().toString();

      expect(rendered, isNot(contains(_salt)));
      expect(rendered, isNot(contains(_hash)));
      expect(rendered, isNot(contains(_enrollment)));
      // And not a fragment of them either (a truncated echo is still a leak).
      expect(rendered, isNot(contains(_salt.substring(0, 8))));
      expect(rendered, isNot(contains(_hash.substring(0, 8))));
      expect(rendered, isNot(contains(_enrollment.substring(0, 8))));

      expect(rendered, contains('set: true'));
      expect(rendered, contains('biometric: true'));
      expect(rendered, contains('wrongCount: 3'));
      expect(rendered, contains('lockedOut: true'));
    });

    test('an empty-hash record renders set: false', () {
      const record = PinLockRecord(
        salt: '',
        pinHash: '',
        biometricEnabled: false,
        wrongCount: 0,
      );
      expect(record.toString(), contains('set: false'));
      expect(record.toString(), contains('lockedOut: false'));
    });

    test('the encoded string is the ONLY place the secrets appear', () {
      // Sanity control: the fixtures really are present in the serialised form,
      // so the negative assertions above cannot pass vacuously.
      final encoded = _aRecord().encode();
      expect(encoded, contains(_salt));
      expect(jsonDecode(encoded), isA<Map<String, dynamic>>());
    });
  });

  group('PinLockSnapshot', () {
    test('a clean absent snapshot is not degraded', () {
      const snapshot = PinLockSnapshot(record: null);
      expect(snapshot.record, isNull);
      expect(snapshot.degraded, isFalse);
    });

    test('toString carries no secrets', () {
      final rendered = PinLockSnapshot(record: _aRecord()).toString();
      expect(rendered, isNot(contains(_salt)));
      expect(rendered, isNot(contains(_hash)));
      expect(rendered, contains('degraded: false'));
    });
  });

  group('readInitialLockSnapshot (the bootstrap helper — ADR-018 D2)', () {
    test('a clean read yields a NON-degraded snapshot', () async {
      final snapshot = await readInitialLockSnapshot(
        _StubStore(() async => _aRecord()),
      );
      expect(snapshot.record, _aRecord());
      expect(snapshot.degraded, isFalse);
    });

    test('a clean ABSENT read yields a non-degraded null (final, D2)', () async {
      final snapshot = await readInitialLockSnapshot(
        _StubStore(() async => null),
      );
      expect(snapshot.record, isNull);
      expect(snapshot.degraded, isFalse);
    });

    test('a THROWING read fails open but marks the snapshot degraded', () async {
      final snapshot = await readInitialLockSnapshot(
        _StubStore(() async => throw StateError('keychain fault')),
      );
      expect(snapshot.record, isNull);
      expect(snapshot.degraded, isTrue);
    });
  });
}

/// A minimal read-only stub — [readInitialLockSnapshot] takes the SEAM, so the
/// bootstrap try/catch is testable without the plugin-backed adapter (D2/TEST-5).
class _StubStore implements PinLockStore {
  _StubStore(this._read);

  final Future<PinLockRecord?> Function() _read;

  @override
  Future<PinLockRecord?> read() => _read();

  @override
  Future<void> write(PinLockRecord record) async {}

  @override
  Future<void> clear() async {}
}
