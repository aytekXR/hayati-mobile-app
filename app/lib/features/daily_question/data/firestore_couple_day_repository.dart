import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/couple_day_assignment.dart';
import '../domain/couple_day_repository.dart';
import 'couple_day_assignment_dto.dart';
import 'couple_failure_mapper.dart';

/// Firestore-backed [CoupleDayRepository] over
/// `couples/{cid}/days/{yyyymmdd}` (docs/architecture.md §3, M3.3). A
/// missing doc streams as null — the honest no-day-yet state; the server
/// assignment is authoritative (ADR-011), so this repository never
/// predicts or fabricates one.
class FirestoreCoupleDayRepository implements CoupleDayRepository {
  FirestoreCoupleDayRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  @override
  Stream<CoupleDayAssignment?> watchDay(String coupleId, String dayKey) async* {
    try {
      await for (final snapshot
          in _firestore
              .collection('couples')
              .doc(coupleId)
              .collection('days')
              .doc(dayKey)
              .snapshots()) {
        final data = snapshot.data();
        yield data == null
            ? null
            : coupleDayAssignmentFromMap(_domainReady(data));
      }
    } catch (failure) {
      throw mapCoupleDataFailure(failure);
    }
  }

  /// Converts the wire types the pure mapper must not know about:
  /// `assignedAt` arrives as a Firestore `Timestamp` and crosses as a
  /// [DateTime]. Junk is left as-is for the mapper to reject loudly.
  Map<String, dynamic> _domainReady(Map<String, dynamic> data) {
    final assignedAt = data['assignedAt'];
    return {
      ...data,
      'assignedAt': assignedAt is Timestamp ? assignedAt.toDate() : assignedAt,
    };
  }
}
