// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [CoachRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// Functions-backed implementation, and tests override it per container with a
/// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.

@ProviderFor(coachRepository)
const coachRepositoryProvider = CoachRepositoryProvider._();

/// Provides the app's [CoachRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// Functions-backed implementation, and tests override it per container with a
/// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.

final class CoachRepositoryProvider
    extends
        $FunctionalProvider<CoachRepository, CoachRepository, CoachRepository>
    with $Provider<CoachRepository> {
  /// Provides the app's [CoachRepository].
  ///
  /// Deliberately unimplemented at the base (same contract as
  /// `inviteRepositoryProvider`): the flavor entrypoints override it with the
  /// Functions-backed implementation, and tests override it per container with a
  /// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
  /// container, not a shared value.
  const CoachRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachRepositoryHash();

  @$internal
  @override
  $ProviderElement<CoachRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoachRepository create(Ref ref) {
    return coachRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachRepository>(value),
    );
  }
}

String _$coachRepositoryHash() => r'5ddfe3abe024e15027797ea11f1bb6d1e084c4de';
