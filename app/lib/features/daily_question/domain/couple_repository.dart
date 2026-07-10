import 'couple.dart';

/// Read seam for `couples/{coupleId}` (M3.3 — the app's first couple read,
/// docs/architecture.md §3). The doc is server-owned (join Function creates,
/// rules freeze the load-bearing fields), so this is watch-only; every
/// failure is mapped into the `CoupleDataException` taxonomy at the data
/// boundary.
abstract interface class CoupleRepository {
  /// Live couple doc (null if it does not exist — corrupt state when
  /// `users.coupleId` points here). Same current-value-then-live-updates
  /// contract as Firestore `snapshots()`.
  Stream<Couple?> watchCouple(String coupleId);
}
