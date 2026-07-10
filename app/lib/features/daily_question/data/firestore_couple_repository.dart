import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/couple.dart';
import '../domain/couple_repository.dart';
import 'couple_dto.dart';
import 'couple_failure_mapper.dart';

/// Firestore-backed [CoupleRepository] over `couples/{coupleId}`
/// (docs/architecture.md §3, M3.3 — the app's first couple read). Every
/// failure crossing this boundary is mapped into the [CoupleDataException]
/// taxonomy — same discipline as `FirestoreSoloAnswersRepository`.
class FirestoreCoupleRepository implements CoupleRepository {
  FirestoreCoupleRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  @override
  Stream<Couple?> watchCouple(String coupleId) async* {
    try {
      await for (final snapshot
          in _firestore.collection('couples').doc(coupleId).snapshots()) {
        final data = snapshot.data();
        yield data == null ? null : coupleFromMap(coupleId, data);
      }
    } catch (failure) {
      throw mapCoupleDataFailure(failure);
    }
  }
}
