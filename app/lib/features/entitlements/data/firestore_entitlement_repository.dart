import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/couple_entitlement.dart';
import '../domain/entitlement_repository.dart';
import 'couple_entitlement_dto.dart';
import 'entitlement_failure_mapper.dart';

/// Firestore-backed [EntitlementRepository] over `subscriptions/{coupleId}`
/// (docs/architecture.md §3, M4.1 — ADR-013 Decision 5). A missing doc streams
/// as null (the free tier — no backfill); every failure crossing this boundary
/// is mapped into the [EntitlementDataException] taxonomy — same discipline as
/// `FirestoreCoupleRepository` (and, like it, no `_domainReady` shim: the
/// mapper owns the one wire-type conversion directly, `expiresAtMs` being a
/// plain int rather than a Firestore `Timestamp`).
class FirestoreEntitlementRepository implements EntitlementRepository {
  FirestoreEntitlementRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  @override
  Stream<CoupleEntitlement?> watchEntitlement(String coupleId) async* {
    try {
      await for (final snapshot
          in _firestore.collection('subscriptions').doc(coupleId).snapshots()) {
        final data = snapshot.data();
        yield data == null ? null : coupleEntitlementFromMap(data);
      }
    } catch (failure) {
      throw mapEntitlementDataFailure(failure);
    }
  }
}
