import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../daily_question/domain/solo_clock.dart';
import '../../domain/couple_entitlement.dart';
import '../../domain/entitlement_repository_provider.dart';

part 'entitlement_providers.g.dart';

/// Riverpod 3 auto-retry disabled (same rationale as `paired_providers.dart`):
/// an error here is a rules denial or corrupt server state, and
/// backoff-hammering just latches the stream on a spinner. The gating decision
/// reads an error as "free until proven entitled" ([isPremium] below), so a
/// latched error fails safe.
Duration? _noRetry(int retryCount, Object error) => null;

/// Live `subscriptions/{coupleId}` mirror (M4.1 — the app's entitlement read,
/// ADR-013 Decision 5). Null = the doc does not exist yet: the free tier
/// (every couple is free until the webhook writes otherwise — no backfill).
@Riverpod(retry: _noRetry)
Stream<CoupleEntitlement?> entitlementStream(Ref ref, String coupleId) =>
    ref.watch(entitlementRepositoryProvider).watchEntitlement(coupleId);

/// The single premium-gating decision point (M4.1, ADR-013 Decision 5). Free
/// until proven entitled: an in-flight first load, a settled (un-retried)
/// error, or an absent doc all read as NOT premium — the AsyncValue-flag
/// precedence idiom (not the subtype; Riverpod 3 carries a previous value/error
/// across states).
///
/// [CoupleEntitlement.entitled] is never sufficient alone (ADR-013 Decision 5,
/// binding on every consumer): a delayed EXPIRATION leaves the mirror
/// `entitled: true` with a past [CoupleEntitlement.expiresAt] for hours, so the
/// boolean is paired with the future-check against the app's single clock seam
/// (`soloClockProvider`). A null `expiresAt` is the non-expiring sentinel and
/// always passes.
@Riverpod(retry: _noRetry)
bool isPremium(Ref ref, {required String coupleId}) {
  final entitlement = ref.watch(entitlementStreamProvider(coupleId));
  if (entitlement.isLoading || entitlement.hasError) return false;
  final couple = entitlement.value;
  if (couple == null || !couple.entitled) return false;
  final expiresAt = couple.expiresAt;
  return expiresAt == null || expiresAt.isAfter(ref.watch(soloClockProvider)());
}
