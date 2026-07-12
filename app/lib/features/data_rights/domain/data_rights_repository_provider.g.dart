// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_rights_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [DataRightsRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `coachRepositoryProvider` / `inviteRepositoryProvider`): the flavor
/// entrypoints override it with the Functions-backed implementation, and tests
/// override it per container with a fake. Use `overrideWith((ref) => …)` — the
/// repository is constructed per container, not a shared value.

@ProviderFor(dataRightsRepository)
const dataRightsRepositoryProvider = DataRightsRepositoryProvider._();

/// Provides the app's [DataRightsRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `coachRepositoryProvider` / `inviteRepositoryProvider`): the flavor
/// entrypoints override it with the Functions-backed implementation, and tests
/// override it per container with a fake. Use `overrideWith((ref) => …)` — the
/// repository is constructed per container, not a shared value.

final class DataRightsRepositoryProvider
    extends
        $FunctionalProvider<
          DataRightsRepository,
          DataRightsRepository,
          DataRightsRepository
        >
    with $Provider<DataRightsRepository> {
  /// Provides the app's [DataRightsRepository].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `coachRepositoryProvider` / `inviteRepositoryProvider`): the flavor
  /// entrypoints override it with the Functions-backed implementation, and tests
  /// override it per container with a fake. Use `overrideWith((ref) => …)` — the
  /// repository is constructed per container, not a shared value.
  const DataRightsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataRightsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataRightsRepositoryHash();

  @$internal
  @override
  $ProviderElement<DataRightsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DataRightsRepository create(Ref ref) {
    return dataRightsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataRightsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataRightsRepository>(value),
    );
  }
}

String _$dataRightsRepositoryHash() =>
    r'd752a96570e953c015bf1da78f96876cdd6a8c8e';
