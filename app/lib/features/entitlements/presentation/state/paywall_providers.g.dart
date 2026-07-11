// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paywall_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The paywall display model, derived from the store's current offerings
/// (ADR-014 Decision 3). Failures surface as the mapped [PurchaseException]
/// taxonomy: the repository already maps its own SDK failures (passed through
/// untouched), `derivePaywallOffering` throws [PaywallUnavailableException]
/// directly, and any non-taxonomy object escaping the fake is mapped here — so
/// the AsyncError always carries a [PurchaseException].

@ProviderFor(paywallOffering)
const paywallOfferingProvider = PaywallOfferingProvider._();

/// The paywall display model, derived from the store's current offerings
/// (ADR-014 Decision 3). Failures surface as the mapped [PurchaseException]
/// taxonomy: the repository already maps its own SDK failures (passed through
/// untouched), `derivePaywallOffering` throws [PaywallUnavailableException]
/// directly, and any non-taxonomy object escaping the fake is mapped here — so
/// the AsyncError always carries a [PurchaseException].

final class PaywallOfferingProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaywallOffering>,
          PaywallOffering,
          FutureOr<PaywallOffering>
        >
    with $FutureModifier<PaywallOffering>, $FutureProvider<PaywallOffering> {
  /// The paywall display model, derived from the store's current offerings
  /// (ADR-014 Decision 3). Failures surface as the mapped [PurchaseException]
  /// taxonomy: the repository already maps its own SDK failures (passed through
  /// untouched), `derivePaywallOffering` throws [PaywallUnavailableException]
  /// directly, and any non-taxonomy object escaping the fake is mapped here — so
  /// the AsyncError always carries a [PurchaseException].
  const PaywallOfferingProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'paywallOfferingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paywallOfferingHash();

  @$internal
  @override
  $FutureProviderElement<PaywallOffering> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaywallOffering> create(Ref ref) {
    return paywallOffering(ref);
  }
}

String _$paywallOfferingHash() => r'9997712a3113bb65ae4ac9a27d079e06145cdf8c';
