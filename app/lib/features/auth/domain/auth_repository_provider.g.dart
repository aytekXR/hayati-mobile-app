// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [AuthRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `appConfigProvider`): the flavor entrypoints override it with the
/// Firebase-backed implementation, and tests override it per container
/// with a fake. Use `overrideWith((ref) => …)` — the repository is
/// constructed per container, not a shared value.

@ProviderFor(authRepository)
const authRepositoryProvider = AuthRepositoryProvider._();

/// Provides the app's [AuthRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `appConfigProvider`): the flavor entrypoints override it with the
/// Firebase-backed implementation, and tests override it per container
/// with a fake. Use `overrideWith((ref) => …)` — the repository is
/// constructed per container, not a shared value.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// Provides the app's [AuthRepository].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `appConfigProvider`): the flavor entrypoints override it with the
  /// Firebase-backed implementation, and tests override it per container
  /// with a fake. Use `overrideWith((ref) => …)` — the repository is
  /// constructed per container, not a shared value.
  const AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'629e8ef01a066ca628aec0322b57247f65007f64';
