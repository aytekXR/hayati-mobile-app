// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_preview_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [InvitePreviewRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// http-backed implementation, and tests override it per container with a fake.
/// Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.

@ProviderFor(invitePreviewRepository)
const invitePreviewRepositoryProvider = InvitePreviewRepositoryProvider._();

/// Provides the app's [InvitePreviewRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// http-backed implementation, and tests override it per container with a fake.
/// Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.

final class InvitePreviewRepositoryProvider
    extends
        $FunctionalProvider<
          InvitePreviewRepository,
          InvitePreviewRepository,
          InvitePreviewRepository
        >
    with $Provider<InvitePreviewRepository> {
  /// Provides the app's [InvitePreviewRepository].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `inviteRepositoryProvider`): the flavor entrypoints override it with the
  /// http-backed implementation, and tests override it per container with a fake.
  /// Use `overrideWith((ref) => …)` — the repository is constructed per
  /// container, not a shared value.
  const InvitePreviewRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invitePreviewRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invitePreviewRepositoryHash();

  @$internal
  @override
  $ProviderElement<InvitePreviewRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvitePreviewRepository create(Ref ref) {
    return invitePreviewRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvitePreviewRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvitePreviewRepository>(value),
    );
  }
}

String _$invitePreviewRepositoryHash() =>
    r'8086b75aea54e9e9ec130805d8dc983fdfe1c479';
