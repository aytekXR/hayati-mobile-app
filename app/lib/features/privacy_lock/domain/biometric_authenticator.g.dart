// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_authenticator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [BiometricAuthenticator].
///
/// Deliberately unimplemented at the base (the repository-seam discipline):
/// the flavor entrypoints override it BY VALUE with a
/// `LocalAuthBiometricAuthenticator`, and tests with a
/// `FakeBiometricAuthenticator` — so `flutter test` never touches the local_auth
/// channel.

@ProviderFor(biometricAuthenticator)
const biometricAuthenticatorProvider = BiometricAuthenticatorProvider._();

/// Provides the app's [BiometricAuthenticator].
///
/// Deliberately unimplemented at the base (the repository-seam discipline):
/// the flavor entrypoints override it BY VALUE with a
/// `LocalAuthBiometricAuthenticator`, and tests with a
/// `FakeBiometricAuthenticator` — so `flutter test` never touches the local_auth
/// channel.

final class BiometricAuthenticatorProvider
    extends
        $FunctionalProvider<
          BiometricAuthenticator,
          BiometricAuthenticator,
          BiometricAuthenticator
        >
    with $Provider<BiometricAuthenticator> {
  /// Provides the app's [BiometricAuthenticator].
  ///
  /// Deliberately unimplemented at the base (the repository-seam discipline):
  /// the flavor entrypoints override it BY VALUE with a
  /// `LocalAuthBiometricAuthenticator`, and tests with a
  /// `FakeBiometricAuthenticator` — so `flutter test` never touches the local_auth
  /// channel.
  const BiometricAuthenticatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricAuthenticatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricAuthenticatorHash();

  @$internal
  @override
  $ProviderElement<BiometricAuthenticator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BiometricAuthenticator create(Ref ref) {
    return biometricAuthenticator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiometricAuthenticator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiometricAuthenticator>(value),
    );
  }
}

String _$biometricAuthenticatorHash() =>
    r'5e2cb3b946c6da9db75a971ca251acc03858448f';
