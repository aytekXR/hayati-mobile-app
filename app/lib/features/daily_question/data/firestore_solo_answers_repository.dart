import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/solo_answer.dart';
import '../domain/solo_answer_exception.dart';
import '../domain/solo_answers_repository.dart';
import 'solo_answer_dto.dart';

/// Firestore-backed [SoloAnswersRepository] over
/// `users/{uid}/soloAnswers/{yyyymmdd}` (docs/architecture.md §3, M2.4).
/// Every failure crossing this boundary is mapped into the
/// [SoloAnswerException] taxonomy — same discipline as
/// `FirestoreProfileRepository`.
class FirestoreSoloAnswersRepository implements SoloAnswersRepository {
  FirestoreSoloAnswersRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String dayKey) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('soloAnswers')
          .doc(dayKey);

  @override
  Stream<SoloAnswer?> watchAnswer(String uid, String dayKey) async* {
    try {
      // Current document immediately on listen, then every change — the
      // contract FakeSoloAnswersRepository mirrors.
      await for (final snapshot in _doc(uid, dayKey).snapshots()) {
        final data = snapshot.data();
        yield data == null ? null : soloAnswerFromMap(_domainReady(data));
      }
    } catch (failure) {
      throw mapSoloAnswerFailure(failure);
    }
  }

  @override
  Future<void> saveAnswer(
    String uid,
    String dayKey, {
    required String questionId,
    required String text,
  }) async {
    try {
      // Full replace, no merge: the doc's whole surface is exactly these
      // three fields (rules-enforced hasOnly), and a same-day re-save is a
      // deliberate overwrite of the day's answer.
      await _doc(uid, dayKey).set({
        'questionId': questionId,
        'text': text,
        // Server-stamped; rules require == request.time so a client clock
        // can never forge the answer time.
        'answeredAt': FieldValue.serverTimestamp(),
      });
    } catch (failure) {
      throw mapSoloAnswerFailure(failure);
    }
  }

  /// Converts the wire types the pure mapper must not know about:
  /// `answeredAt` arrives as a Firestore `Timestamp` (or null while a local
  /// echo's server stamp is pending) and crosses as a [DateTime]. Junk is
  /// left as-is for `soloAnswerFromMap` to reject loudly.
  Map<String, dynamic> _domainReady(Map<String, dynamic> data) {
    final answeredAt = data['answeredAt'];
    return {
      ...data,
      'answeredAt': answeredAt is Timestamp ? answeredAt.toDate() : answeredAt,
    };
  }
}

/// Boundary enforcement for the Firestore error surface, mirroring
/// `mapFirestoreFailure`: transient availability → network, rules/auth
/// denial → permission, everything else keeps its raw code.
SoloAnswerException mapSoloAnswerFailure(Object failure) {
  if (failure is SoloAnswerException) return failure;
  if (failure is FirebaseException) {
    return switch (failure.code) {
      'unavailable' || 'deadline-exceeded' => SoloAnswerNetworkException(
        message: failure.message,
      ),
      'permission-denied' || 'unauthenticated' => SoloAnswerPermissionException(
        message: failure.message,
      ),
      _ => SoloAnswerUnknownException(
        code: failure.code,
        message: failure.message,
      ),
    };
  }
  return SoloAnswerUnknownException(code: 'unexpected', message: '$failure');
}
