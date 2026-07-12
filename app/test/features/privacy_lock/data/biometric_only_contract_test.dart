import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A SOURCE-SENTINEL test — it reads the adapter's source from disk and asserts a
/// literal, exactly like the coach ARB digit-run guard.
///
/// WHY this shape, and why it is not a normal test: the real
/// `LocalAuthBiometricAuthenticator` cannot be instantiated under `flutter test`
/// (it reaches the local_auth platform channel), and the fake cannot express the
/// guarantee either — a fake has no device passcode to fall back to. So the ONLY
/// way to keep the blocking guarantee regression-proof in CI is to pin the source.
///
/// THE GUARANTEE (ADR-018 Decisions 1/7; blocking review finding TEST-1):
/// biometric authentication MUST be biometric-ONLY —
/// `deviceOwnerAuthenticationWithBiometrics`, i.e. `biometricOnly: true` — and
/// NEVER plain `deviceOwnerAuthentication`. The latter offers the DEVICE PASSCODE
/// as a fallback, and the phone-holding partner this product defends against
/// plausibly knows the device passcode. That would be a side door straight past
/// the app PIN: the whole lock, defeated by a fallback flag.
///
/// If this test fails, do not delete it. Restore the flag.
void main() {
  const path =
      'lib/features/privacy_lock/data/local_auth_biometric_authenticator.dart';

  late String source;

  setUpAll(() {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'the sentinel must fail loudly if the adapter is renamed or moved '
          'rather than pass vacuously — re-point this path and keep the pin',
    );
    source = file.readAsStringSync();
  });

  test('the local_auth call pins biometricOnly: true (TEST-1, blocking)', () {
    expect(
      source,
      contains('biometricOnly: true'),
      reason: 'a device-passcode fallback is an app-PIN side door (ADR-018 D1)',
    );
  });

  test('it never asks for the passcode-fallback policy', () {
    // local_auth 3.x expresses the fallback by OMITTING biometricOnly (it
    // defaults to false) — so the positive pin above is the real guard. These
    // catch a future rewrite that reaches for the policy explicitly.
    expect(source, isNot(contains('biometricOnly: false')));
    expect(source, isNot(contains('deviceOwnerAuthentication)')));
  });

  test('every local_auth call is wrapped so a throw becomes false/null (TEST-4)',
      () {
    // local_auth 3.x THROWS LocalAuthException for most failure cases; the seam's
    // bool/null contract is the adapter's obligation, and every failure must fall
    // back to the PIN keypad.
    expect(
      'catch (_)'.allMatches(source).length,
      greaterThanOrEqualTo(3),
      reason: 'isAvailable, authenticate and enrollmentState must each catch',
    );
  });
}
