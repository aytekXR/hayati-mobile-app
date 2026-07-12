import 'package:local_auth/local_auth.dart';

import '../../../core/platform/device_privacy_channel.dart';
import '../domain/biometric_authenticator.dart';

/// [BiometricAuthenticator] over `local_auth` 3.x plus the device-privacy channel
/// (ADR-018 Decisions 1/6/7).
///
/// Its own file, constructed ONLY in the entrypoints: `flutter test` never
/// imports it (the plugin channel would blow up, and the device-only code would
/// pollute the coverage denominator — review finding TEST-5). The two guarantees
/// it must carry are therefore pinned differently:
///
/// 1. **`biometricOnly: true` is load-bearing and non-negotiable** — it maps to
///    iOS `deviceOwnerAuthenticationWithBiometrics`. Plain
///    `deviceOwnerAuthentication` would offer the DEVICE PASSCODE as a fallback,
///    and the phone-holding partner this product defends against plausibly knows
///    it: that is an app-PIN side door (ADR-018 D1/D7, blocking review finding
///    TEST-1). A source-sentinel test (`biometric_only_contract_test.dart`) pins
///    the literal below in CI, because no fake can surface it.
/// 2. **Every call is wrapped in try/catch** — local_auth 3.x THROWS
///    (`LocalAuthException`) for most failure cases rather than returning false
///    (review finding TEST-4). The seam's bool/null contract is this adapter's
///    obligation; every failure falls back to the PIN keypad.
///
/// `enrollmentState` does NOT go through local_auth (it exposes no such API): it
/// reads `LAContext.evaluatedPolicyDomainState` over the one device-privacy
/// channel (Decision 6).
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({
    LocalAuthentication? localAuth,
    DevicePrivacyChannel? channel,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _channel = channel ?? const DevicePrivacyChannel();

  final LocalAuthentication _localAuth;
  final DevicePrivacyChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _localAuth.canCheckBiometrics) return false;
      // Hardware capability is not enough: something must actually be ENROLLED
      // and available to this app, or the prompt would fail at the worst moment.
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        // See guarantee (1) in the class doc — do NOT relax this.
        biometricOnly: true,
        // local_auth 3.x renamed `stickyAuth`: the biometric prompt drives the
        // app through `inactive`, and on a system-triggered backgrounding we want
        // the plugin to resume the attempt rather than fail it.
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Guarantee (2): LocalAuthException (userCanceled, biometricLockout,
      // noBiometricsEnrolled, …) and anything else → false → the PIN keypad.
      return false;
    }
  }

  @override
  Future<String?> enrollmentState() async {
    try {
      return await _channel.biometricEnrollmentState();
    } catch (_) {
      // Null reads as "unavailable", which the controller treats as a REVOKE
      // trigger when biometric was enabled — fail toward the PIN, never toward
      // an accelerator we can no longer validate (D1).
      return null;
    }
  }
}
