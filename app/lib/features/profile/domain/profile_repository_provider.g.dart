// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [ProfileRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `authRepositoryProvider`): the flavor entrypoints override it with the
/// Firestore-backed implementation, and tests override it per container
/// with a fake. Use `overrideWith((ref) => …)` — the repository is
/// constructed per container, not a shared value.

@ProviderFor(profileRepository)
const profileRepositoryProvider = ProfileRepositoryProvider._();

/// Provides the app's [ProfileRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `authRepositoryProvider`): the flavor entrypoints override it with the
/// Firestore-backed implementation, and tests override it per container
/// with a fake. Use `overrideWith((ref) => …)` — the repository is
/// constructed per container, not a shared value.

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository,
          ProfileRepository,
          ProfileRepository
        >
    with $Provider<ProfileRepository> {
  /// Provides the app's [ProfileRepository].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `authRepositoryProvider`): the flavor entrypoints override it with the
  /// Firestore-backed implementation, and tests override it per container
  /// with a fake. Use `overrideWith((ref) => …)` — the repository is
  /// constructed per container, not a shared value.
  const ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository>(value),
    );
  }
}

String _$profileRepositoryHash() => r'a1c82fddb6aba9eb20288bf4ea71e6620041b009';
