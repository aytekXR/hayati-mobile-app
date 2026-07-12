// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_lock_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [PinLockStore].
///
/// Deliberately unimplemented at the base (the repository-seam discipline
/// everywhere else): the flavor entrypoints override it BY VALUE with a
/// `SecureStoragePinLockStore`, and tests override it with a `FakePinLockStore`.

@ProviderFor(pinLockStore)
const pinLockStoreProvider = PinLockStoreProvider._();

/// Provides the app's [PinLockStore].
///
/// Deliberately unimplemented at the base (the repository-seam discipline
/// everywhere else): the flavor entrypoints override it BY VALUE with a
/// `SecureStoragePinLockStore`, and tests override it with a `FakePinLockStore`.

final class PinLockStoreProvider
    extends $FunctionalProvider<PinLockStore, PinLockStore, PinLockStore>
    with $Provider<PinLockStore> {
  /// Provides the app's [PinLockStore].
  ///
  /// Deliberately unimplemented at the base (the repository-seam discipline
  /// everywhere else): the flavor entrypoints override it BY VALUE with a
  /// `SecureStoragePinLockStore`, and tests override it with a `FakePinLockStore`.
  const PinLockStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinLockStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinLockStoreHash();

  @$internal
  @override
  $ProviderElement<PinLockStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PinLockStore create(Ref ref) {
    return pinLockStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PinLockStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PinLockStore>(value),
    );
  }
}

String _$pinLockStoreHash() => r'4632e4d40cf6741f301ae777d20997c7617de91a';

/// The boot snapshot, overridden BY VALUE at bootstrap (and per test container).
/// Never read after `build()` seeds the controller: it is a boot-time constant,
/// and re-running the controller's `build()` against it would replay boot state
/// (which is exactly why nothing may `ref.invalidate` the lock controller —
/// ADR-018 Decision 1, review finding FLUTTER-2).

@ProviderFor(initialLockSnapshot)
const initialLockSnapshotProvider = InitialLockSnapshotProvider._();

/// The boot snapshot, overridden BY VALUE at bootstrap (and per test container).
/// Never read after `build()` seeds the controller: it is a boot-time constant,
/// and re-running the controller's `build()` against it would replay boot state
/// (which is exactly why nothing may `ref.invalidate` the lock controller —
/// ADR-018 Decision 1, review finding FLUTTER-2).

final class InitialLockSnapshotProvider
    extends
        $FunctionalProvider<PinLockSnapshot, PinLockSnapshot, PinLockSnapshot>
    with $Provider<PinLockSnapshot> {
  /// The boot snapshot, overridden BY VALUE at bootstrap (and per test container).
  /// Never read after `build()` seeds the controller: it is a boot-time constant,
  /// and re-running the controller's `build()` against it would replay boot state
  /// (which is exactly why nothing may `ref.invalidate` the lock controller —
  /// ADR-018 Decision 1, review finding FLUTTER-2).
  const InitialLockSnapshotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialLockSnapshotProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialLockSnapshotHash();

  @$internal
  @override
  $ProviderElement<PinLockSnapshot> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PinLockSnapshot create(Ref ref) {
    return initialLockSnapshot(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PinLockSnapshot value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PinLockSnapshot>(value),
    );
  }
}

String _$initialLockSnapshotHash() =>
    r'892b9ecb072ba39b324a4a765bf642622cdf0110';
