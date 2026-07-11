import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/purchases_failure_mapper.dart';
import '../../domain/paywall_offering.dart';
import '../../domain/purchase_exception.dart';
import '../../domain/purchases_repository_provider.dart';

part 'paywall_providers.g.dart';

/// Riverpod 3 auto-retry disabled (same rationale as `entitlement_providers`):
/// an offerings failure is a typed taxonomy error the paywall renders as an
/// honest state (network-retry vs unavailable), so backoff-hammering would just
/// latch a spinner. The screen re-fetches explicitly via `ref.invalidate`.
Duration? _noRetry(int retryCount, Object error) => null;

/// The paywall display model, derived from the store's current offerings
/// (ADR-014 Decision 3). Failures surface as the mapped [PurchaseException]
/// taxonomy: the repository already maps its own SDK failures (passed through
/// untouched), `derivePaywallOffering` throws [PaywallUnavailableException]
/// directly, and any non-taxonomy object escaping the fake is mapped here — so
/// the AsyncError always carries a [PurchaseException].
@Riverpod(retry: _noRetry)
Future<PaywallOffering> paywallOffering(Ref ref) async {
  try {
    final offerings = await ref
        .watch(purchasesRepositoryProvider)
        .fetchOfferings();
    return derivePaywallOffering(offerings);
  } on PurchaseException {
    rethrow;
  } catch (failure) {
    throw mapPurchasesFailure(failure);
  }
}
