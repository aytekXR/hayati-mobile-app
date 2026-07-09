// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deep_link_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [DeepLinkSource].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// app_links-backed adapter, and tests override it per container with a fake.

@ProviderFor(deepLinkSource)
const deepLinkSourceProvider = DeepLinkSourceProvider._();

/// Provides the app's [DeepLinkSource].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// app_links-backed adapter, and tests override it per container with a fake.

final class DeepLinkSourceProvider
    extends $FunctionalProvider<DeepLinkSource, DeepLinkSource, DeepLinkSource>
    with $Provider<DeepLinkSource> {
  /// Provides the app's [DeepLinkSource].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `inviteRepositoryProvider`): the flavor entrypoints override it with the
  /// app_links-backed adapter, and tests override it per container with a fake.
  const DeepLinkSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deepLinkSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deepLinkSourceHash();

  @$internal
  @override
  $ProviderElement<DeepLinkSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeepLinkSource create(Ref ref) {
    return deepLinkSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeepLinkSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeepLinkSource>(value),
    );
  }
}

String _$deepLinkSourceHash() => r'f51b3b9c22358ea867412896b5f2131020dd1ccc';
