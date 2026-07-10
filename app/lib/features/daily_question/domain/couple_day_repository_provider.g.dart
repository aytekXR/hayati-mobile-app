// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'couple_day_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for [CoupleDayRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

@ProviderFor(coupleDayRepository)
const coupleDayRepositoryProvider = CoupleDayRepositoryProvider._();

/// Seam for [CoupleDayRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

final class CoupleDayRepositoryProvider
    extends
        $FunctionalProvider<
          CoupleDayRepository,
          CoupleDayRepository,
          CoupleDayRepository
        >
    with $Provider<CoupleDayRepository> {
  /// Seam for [CoupleDayRepository]: bound to the Firestore implementation at
  /// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
  /// same throw-until-overridden discipline as `profileRepositoryProvider`.
  const CoupleDayRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coupleDayRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coupleDayRepositoryHash();

  @$internal
  @override
  $ProviderElement<CoupleDayRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CoupleDayRepository create(Ref ref) {
    return coupleDayRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoupleDayRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoupleDayRepository>(value),
    );
  }
}

String _$coupleDayRepositoryHash() =>
    r'6ce1893f6726aa0fb2aaf2a33cf28d782ce6bcf4';
