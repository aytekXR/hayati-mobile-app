/// The rules-enforced ceiling on couple answer text (`firestore.rules`
/// answers block: `text.size() <= 2000` — the same bound as
/// `soloAnswerMaxLength`, kept as its own constant so the two surfaces can
/// diverge deliberately, never accidentally). The entry field hard-caps at
/// this number; the server rule stays defense-in-depth.
const int coupleAnswerMaxLength = 2000;

/// One persisted couple answer (M3.3):
/// `couples/{cid}/days/{yyyymmdd}/answers/{authorUid}`,
/// docs/architecture.md §3. Pure Dart, keyed externally by coupleId +
/// dayKey + author uid. The partner's doc is reveal-gated server-side —
/// unreadable until the requester's own answer exists.
class CoupleAnswer {
  const CoupleAnswer({
    required this.questionId,
    required this.text,
    this.answeredAt,
  });

  /// Rules-pinned to the day doc's assigned questionId.
  final String questionId;

  final String text;

  /// Server stamp of the last save. Null only inside the pending
  /// serverTimestamp window (the local echo of an unacked write) — which is
  /// exactly the signal the partner-slot gate waits out: the partner stream
  /// attaches only once this is non-null (server-acked), so the reveal
  /// listen can never race the own answer's commit.
  final DateTime? answeredAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleAnswer &&
          other.questionId == questionId &&
          other.text == text &&
          other.answeredAt == answeredAt;

  @override
  int get hashCode => Object.hash(questionId, text, answeredAt);

  @override
  String toString() =>
      'CoupleAnswer(questionId: $questionId, text: $text, '
      'answeredAt: $answeredAt)';
}
