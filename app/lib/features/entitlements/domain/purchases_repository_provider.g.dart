// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for [PurchasesRepository]: bound to the RevenueCat adapter at bootstrap
/// (main_dev.dart / main_prod.dart), faked per test container — same
/// throw-until-overridden discipline as `entitlementRepositoryProvider`. A
/// signed-out lifecycle never resolves it (the identity sync reads it lazily,
/// only when a sync action fires), so a signed-out pump needs no override.

@ProviderFor(purchasesRepository)
const purchasesRepositoryProvider = PurchasesRepositoryProvider._();

/// Seam for [PurchasesRepository]: bound to the RevenueCat adapter at bootstrap
/// (main_dev.dart / main_prod.dart), faked per test container — same
/// throw-until-overridden discipline as `entitlementRepositoryProvider`. A
/// signed-out lifecycle never resolves it (the identity sync reads it lazily,
/// only when a sync action fires), so a signed-out pump needs no override.

final class PurchasesRepositoryProvider
    extends
        $FunctionalProvider<
          PurchasesRepository,
          PurchasesRepository,
          PurchasesRepository
        >
    with $Provider<PurchasesRepository> {
  /// Seam for [PurchasesRepository]: bound to the RevenueCat adapter at bootstrap
  /// (main_dev.dart / main_prod.dart), faked per test container — same
  /// throw-until-overridden discipline as `entitlementRepositoryProvider`. A
  /// signed-out lifecycle never resolves it (the identity sync reads it lazily,
  /// only when a sync action fires), so a signed-out pump needs no override.
  const PurchasesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchasesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchasesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PurchasesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PurchasesRepository create(Ref ref) {
    return purchasesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PurchasesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PurchasesRepository>(value),
    );
  }
}

String _$purchasesRepositoryHash() =>
    r'3cff3de1414e452747b8cd8c98adc7ba4d1d1fe1';
