// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'couple_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for [CoupleRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

@ProviderFor(coupleRepository)
const coupleRepositoryProvider = CoupleRepositoryProvider._();

/// Seam for [CoupleRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.

final class CoupleRepositoryProvider
    extends
        $FunctionalProvider<
          CoupleRepository,
          CoupleRepository,
          CoupleRepository
        >
    with $Provider<CoupleRepository> {
  /// Seam for [CoupleRepository]: bound to the Firestore implementation at
  /// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
  /// same throw-until-overridden discipline as `profileRepositoryProvider`.
  const CoupleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coupleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coupleRepositoryHash();

  @$internal
  @override
  $ProviderElement<CoupleRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoupleRepository create(Ref ref) {
    return coupleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoupleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoupleRepository>(value),
    );
  }
}

String _$coupleRepositoryHash() => r'9dd2dd317c69275ec83581adf36dc159c55555a2';
