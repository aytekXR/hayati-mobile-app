// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [PushTokenRepository].
///
/// Unimplemented at the base, like `dataRightsRepositoryProvider`: the flavor
/// entrypoints override it with the Functions-backed implementation and tests
/// override it per container with a fake.

@ProviderFor(pushTokenRepository)
const pushTokenRepositoryProvider = PushTokenRepositoryProvider._();

/// Provides the app's [PushTokenRepository].
///
/// Unimplemented at the base, like `dataRightsRepositoryProvider`: the flavor
/// entrypoints override it with the Functions-backed implementation and tests
/// override it per container with a fake.

final class PushTokenRepositoryProvider
    extends
        $FunctionalProvider<
          PushTokenRepository,
          PushTokenRepository,
          PushTokenRepository
        >
    with $Provider<PushTokenRepository> {
  /// Provides the app's [PushTokenRepository].
  ///
  /// Unimplemented at the base, like `dataRightsRepositoryProvider`: the flavor
  /// entrypoints override it with the Functions-backed implementation and tests
  /// override it per container with a fake.
  const PushTokenRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushTokenRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushTokenRepositoryHash();

  @$internal
  @override
  $ProviderElement<PushTokenRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PushTokenRepository create(Ref ref) {
    return pushTokenRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushTokenRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushTokenRepository>(value),
    );
  }
}

String _$pushTokenRepositoryHash() =>
    r'74f8be660113d424b4ded6e3564b6506e4bc1a71';
