/// The rules-enforced ceiling on answer text (`firestore.rules`:
/// `text.size() <= 2000`). The entry field hard-caps at the same number so an
/// over-length save is unrepresentable client-side — the server rule stays
/// defense-in-depth, never a user-facing dead end.
const int soloAnswerMaxLength = 2000;

/// One persisted solo reflection answer (M2.4):
/// `users/{uid}/soloAnswers/{yyyymmdd}`, docs/architecture.md §3. Pure Dart,
/// keyed externally by uid + day key.
class SoloAnswer {
  const SoloAnswer({
    required this.questionId,
    required this.text,
    this.answeredAt,
  });

  /// The pack question this answers — kept on the doc so the M3 post-pairing
  /// surface can re-associate history even if a future pack version reorders
  /// days.
  final String questionId;

  final String text;

  /// Server stamp of the last save. Null only inside the pending
  /// serverTimestamp window (the local echo of an unacked write).
  final DateTime? answeredAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoloAnswer &&
          other.questionId == questionId &&
          other.text == text &&
          other.answeredAt == answeredAt;

  @override
  int get hashCode => Object.hash(questionId, text, answeredAt);

  @override
  String toString() =>
      'SoloAnswer(questionId: $questionId, text: $text, '
      'answeredAt: $answeredAt)';
}
