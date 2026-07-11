// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entitlement_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seam for [EntitlementRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container — same
/// throw-until-overridden discipline as `coupleRepositoryProvider`.

@ProviderFor(entitlementRepository)
const entitlementRepositoryProvider = EntitlementRepositoryProvider._();

/// Seam for [EntitlementRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container — same
/// throw-until-overridden discipline as `coupleRepositoryProvider`.

final class EntitlementRepositoryProvider
    extends
        $FunctionalProvider<
          EntitlementRepository,
          EntitlementRepository,
          EntitlementRepository
        >
    with $Provider<EntitlementRepository> {
  /// Seam for [EntitlementRepository]: bound to the Firestore implementation at
  /// bootstrap (main_dev.dart / main_prod.dart), faked per test container — same
  /// throw-until-overridden discipline as `coupleRepositoryProvider`.
  const EntitlementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementRepositoryHash();

  @$internal
  @override
  $ProviderElement<EntitlementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntitlementRepository create(Ref ref) {
    return entitlementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementRepository>(value),
    );
  }
}

String _$entitlementRepositoryHash() =>
    r'a42a3ccc8ead48e2ed156964220ec261a9fe4b51';
