import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/privacy_lock/domain/pin_hasher.dart';

/// The PIN every lock test types. Six digits (the fixed credential length).
const String kTestPin = '123456';

/// A different, equally valid PIN — the wrong-attempt fixture.
const String kWrongPin = '654321';

/// A fixed salt, so records are reproducible across a "relaunch" (a fresh
/// container over the same [FakePinLockStore] contents). Real records use
/// `generateSalt()`; the hash math is unit-tested separately.
final String kTestSalt = base64Encode(List<int>.filled(16, 7));

/// A lock record for [pin], with whatever bounding/biometric state a test needs.
PinLockRecord lockRecord({
  String pin = kTestPin,
  bool biometricEnabled = false,
  String? enrollment,
  int wrongCount = 0,
  int? lockoutUntilMs,
}) => PinLockRecord(
  salt: kTestSalt,
  pinHash: hashPin(pin: pin, salt: kTestSalt),
  biometricEnabled: biometricEnabled,
  biometricEnrollmentState: enrollment,
  wrongCount: wrongCount,
  lockoutUntilMs: lockoutUntilMs,
);

/// A boot snapshot with the lock ENABLED (the cold-start-locked fixture).
PinLockSnapshot lockedSnapshot({
  bool biometricEnabled = false,
  String? enrollment,
  int wrongCount = 0,
  int? lockoutUntilMs,
}) => PinLockSnapshot(
  record: lockRecord(
    biometricEnabled: biometricEnabled,
    enrollment: enrollment,
    wrongCount: wrongCount,
    lockoutUntilMs: lockoutUntilMs,
  ),
);

/// A boot snapshot with NO record — the free-tier / lock-never-set-up default.
const PinLockSnapshot noLockSnapshot = PinLockSnapshot(record: null);

/// Types [pin] on the in-app keypad (the only place a digit can be entered).
Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
