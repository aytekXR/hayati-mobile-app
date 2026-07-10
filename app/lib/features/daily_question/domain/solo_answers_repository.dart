import 'solo_answer.dart';

/// Persistence seam for `users/{uid}/soloAnswers/{yyyymmdd}` (M2.4,
/// docs/architecture.md §3). Firestore-backed in production so solo history
/// survives reinstall and can surface post-pairing at M3; every failure is
/// mapped into the `SoloAnswerException` taxonomy at the data boundary.
abstract interface class SoloAnswersRepository {
  /// Live answer for one day bucket (null while unanswered). Same
  /// current-value-then-live-updates contract as Firestore `snapshots()`.
  Stream<SoloAnswer?> watchAnswer(String uid, String dayKey);

  /// Creates or replaces the day's answer. The server stamps `answeredAt`
  /// (rules-enforced `== request.time`); the client never supplies it.
  Future<void> saveAnswer(
    String uid,
    String dayKey, {
    required String questionId,
    required String text,
  });
}
