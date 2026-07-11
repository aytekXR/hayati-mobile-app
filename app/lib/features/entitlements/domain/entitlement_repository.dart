import 'couple_entitlement.dart';

/// Read seam for `subscriptions/{coupleId}` (M4.1, ADR-013 Decision 5). The
/// doc is server-owned — the `revenueCatWebhook` Function (admin SDK) is the
/// sole writer and rules deny every client write — so this is watch-only;
/// every failure is mapped into the `EntitlementDataException` taxonomy at the
/// data boundary, same discipline as [CoupleRepository].
abstract interface class EntitlementRepository {
  /// Live entitlement mirror (null when the doc does not exist — the free
  /// tier: every couple is free until the webhook writes otherwise, no
  /// backfill, ADR-013 Decision 5). Same current-value-then-live-updates
  /// contract as Firestore `snapshots()`.
  Stream<CoupleEntitlement?> watchEntitlement(String coupleId);
}
