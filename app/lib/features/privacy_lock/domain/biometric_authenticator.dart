import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_authenticator.g.dart';

/// The biometric ACCELERATOR seam (ADR-018 Decisions 1/7). Biometric is never the
/// credential — the PIN is (biometrics are enrollment-mutable on a shared device,
/// and the platform cannot tell us WHOSE face passed). Every failure mode returns
/// `false`/`null` and falls back to the PIN keypad.
abstract interface class BiometricAuthenticator {
  /// Whether biometric auth can be offered at all right now (hardware present,
  /// something enrolled, permission granted). False on any error.
  Future<bool> isAvailable();

  /// Prompts for biometric auth. Returns false on ANY failure, cancel, or
  /// unavailability — the adapter's obligation, not free plugin behaviour:
  /// local_auth 3.x THROWS (`LocalAuthException`) for most failure cases
  /// (review finding TEST-4), and the adapter maps them all to false.
  ///
  /// CONTRACT — this MUST be biometric-only
  /// (iOS `deviceOwnerAuthenticationWithBiometrics`, i.e. `biometricOnly: true`),
  /// NEVER plain `deviceOwnerAuthentication`. The latter offers the DEVICE
  /// PASSCODE as a fallback, and the phone-holding partner this product defends
  /// against plausibly knows the device passcode — a device-passcode side door
  /// would defeat the app PIN entirely (ADR-018 D1/D7; blocking review finding
  /// TEST-1). The fake cannot surface this, so the guarantee is carried by this
  /// contract line plus a source-sentinel test over the real adapter.
  Future<bool> authenticate({required String reason});

  /// The opaque platform biometric-enrollment state (iOS
  /// `LAContext.evaluatedPolicyDomainState`, base64 over the device-privacy
  /// channel), or null when biometrics are unavailable / on any error.
  ///
  /// A CHANGE in this value revokes biometric unlock (ADR-018 Decision 1): a
  /// partner who adds their face or finger AFTER the user enabled the
  /// accelerator gains nothing — the record is rewritten with biometric off and
  /// the PIN is required again.
  Future<String?> enrollmentState();
}

/// Provides the app's [BiometricAuthenticator].
///
/// Deliberately unimplemented at the base (the repository-seam discipline):
/// the flavor entrypoints override it BY VALUE with a
/// `LocalAuthBiometricAuthenticator`, and tests with a
/// `FakeBiometricAuthenticator` — so `flutter test` never touches the local_auth
/// channel.
@Riverpod(keepAlive: true)
BiometricAuthenticator biometricAuthenticator(Ref ref) => throw StateError(
  'biometricAuthenticatorProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
