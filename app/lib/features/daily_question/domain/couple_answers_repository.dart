import 'couple_answer.dart';

/// Persistence seam for `couples/{cid}/days/{dayKey}/answers/{authorUid}`
/// (M3.3, docs/architecture.md §3). The reveal invariant is SERVER-side
/// (rules): watching the partner's doc before the requester's own answer
/// exists is denied — the provider layer never attaches that watch until
/// the own answer is server-acked, and maps a denial to the locked state as
/// defense-in-depth. Every failure is mapped into the `CoupleDataException`
/// taxonomy at the data boundary.
abstract interface class CoupleAnswersRepository {
  /// Live answer doc of [authorUid] (null while unanswered). For the
  /// partner's uid this is the reveal-gated read.
  Stream<CoupleAnswer?> watchAnswer(
    String coupleId,
    String dayKey,
    String authorUid,
  );

  /// Creates or replaces the caller's own answer. Full replace by rules
  /// contract (the doc surface is exactly these fields plus the server
  /// stamp); [questionId] must be the day doc's assigned questionId
  /// (rules-pinned). The server stamps `answeredAt`; the client never
  /// supplies it. Rules freeze the doc once BOTH answers exist — a save
  /// after reveal fails with a permission denial.
  Future<void> saveAnswer(
    String coupleId,
    String dayKey, {
    required String authorUid,
    required String questionId,
    required String text,
  });
}
