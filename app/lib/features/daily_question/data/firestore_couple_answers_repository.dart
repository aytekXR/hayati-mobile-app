import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/couple_answer.dart';
import '../domain/couple_answers_repository.dart';
import 'couple_answer_dto.dart';
import 'couple_failure_mapper.dart';

/// Firestore-backed [CoupleAnswersRepository] over
/// `couples/{cid}/days/{dayKey}/answers/{authorUid}`
/// (docs/architecture.md §3, M3.3). The reveal gate lives in the rules; a
/// permission denial on the partner watch means "still locked" and is
/// mapped (not swallowed) so the provider layer can render it as such.
class FirestoreCoupleAnswersRepository implements CoupleAnswersRepository {
  FirestoreCoupleAnswersRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(
    String coupleId,
    String dayKey,
    String authorUid,
  ) => _firestore
      .collection('couples')
      .doc(coupleId)
      .collection('days')
      .doc(dayKey)
      .collection('answers')
      .doc(authorUid);

  @override
  Stream<CoupleAnswer?> watchAnswer(
    String coupleId,
    String dayKey,
    String authorUid,
  ) async* {
    try {
      // Current document immediately on listen, then every change — the
      // contract FakeCoupleAnswersRepository mirrors.
      await for (final snapshot in _doc(
        coupleId,
        dayKey,
        authorUid,
      ).snapshots()) {
        final data = snapshot.data();
        yield data == null ? null : coupleAnswerFromMap(_domainReady(data));
      }
    } catch (failure) {
      throw mapCoupleDataFailure(failure);
    }
  }

  @override
  Future<void> saveAnswer(
    String coupleId,
    String dayKey, {
    required String authorUid,
    required String questionId,
    required String text,
  }) async {
    try {
      // Full replace, no merge: the doc's whole surface is exactly these
      // three fields (rules-enforced hasOnly), and a merge patching text
      // alone would fail the rules' answeredAt == request.time check anyway
      // — the stamp must be re-sent on every legal write.
      await _doc(coupleId, dayKey, authorUid).set({
        'questionId': questionId,
        'text': text,
        // Server-stamped; rules require == request.time so a client clock
        // can never forge the answer time.
        'answeredAt': FieldValue.serverTimestamp(),
      });
    } catch (failure) {
      throw mapCoupleDataFailure(failure);
    }
  }

  /// Converts the wire types the pure mapper must not know about:
  /// `answeredAt` arrives as a Firestore `Timestamp` (or null while a local
  /// echo's server stamp is pending) and crosses as a [DateTime].
  Map<String, dynamic> _domainReady(Map<String, dynamic> data) {
    final answeredAt = data['answeredAt'];
    return {
      ...data,
      'answeredAt': answeredAt is Timestamp ? answeredAt.toDate() : answeredAt,
    };
  }
}
