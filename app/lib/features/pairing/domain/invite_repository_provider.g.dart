// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [InviteRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `profileRepositoryProvider`): the flavor entrypoints override it with the
/// Functions-backed implementation, and tests override it per container with a
/// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.

@ProviderFor(inviteRepository)
const inviteRepositoryProvider = InviteRepositoryProvider._();

/// Provides the app's [InviteRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `profileRepositoryProvider`): the flavor entrypoints override it with the
/// Functions-backed implementation, and tests override it per container with a
/// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.

final class InviteRepositoryProvider
    extends
        $FunctionalProvider<
          InviteRepository,
          InviteRepository,
          InviteRepository
        >
    with $Provider<InviteRepository> {
  /// Provides the app's [InviteRepository].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `profileRepositoryProvider`): the flavor entrypoints override it with the
  /// Functions-backed implementation, and tests override it per container with a
  /// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
  /// container, not a shared value.
  const InviteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inviteRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inviteRepositoryHash();

  @$internal
  @override
  $ProviderElement<InviteRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InviteRepository create(Ref ref) {
    return inviteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InviteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InviteRepository>(value),
    );
  }
}

String _$inviteRepositoryHash() => r'b64e17f39e2c2d43817cbf30cb34633e42972779';
