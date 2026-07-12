// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_flag_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [LocalFlagStore].
///
/// Deliberately unimplemented at the base (the repository-seam discipline
/// everywhere else): the flavor entrypoints override it BY VALUE with a
/// `SharedPreferencesLocalFlagStore` built from an already-awaited
/// `SharedPreferences` instance (the entrypoints are async), and tests override
/// it with a `FakeLocalFlagStore`.

@ProviderFor(localFlagStore)
const localFlagStoreProvider = LocalFlagStoreProvider._();

/// Provides the app's [LocalFlagStore].
///
/// Deliberately unimplemented at the base (the repository-seam discipline
/// everywhere else): the flavor entrypoints override it BY VALUE with a
/// `SharedPreferencesLocalFlagStore` built from an already-awaited
/// `SharedPreferences` instance (the entrypoints are async), and tests override
/// it with a `FakeLocalFlagStore`.

final class LocalFlagStoreProvider
    extends $FunctionalProvider<LocalFlagStore, LocalFlagStore, LocalFlagStore>
    with $Provider<LocalFlagStore> {
  /// Provides the app's [LocalFlagStore].
  ///
  /// Deliberately unimplemented at the base (the repository-seam discipline
  /// everywhere else): the flavor entrypoints override it BY VALUE with a
  /// `SharedPreferencesLocalFlagStore` built from an already-awaited
  /// `SharedPreferences` instance (the entrypoints are async), and tests override
  /// it with a `FakeLocalFlagStore`.
  const LocalFlagStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localFlagStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localFlagStoreHash();

  @$internal
  @override
  $ProviderElement<LocalFlagStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalFlagStore create(Ref ref) {
    return localFlagStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalFlagStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalFlagStore>(value),
    );
  }
}

String _$localFlagStoreHash() => r'3662813b98e50b31fdedfb332652ccca703c34bf';
