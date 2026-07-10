/// One day's server-assigned question metadata (M3.2/M3.3):
/// `couples/{cid}/days/{yyyymmdd}`, docs/architecture.md §3. Written
/// exclusively by the rollover Function (metadata ONLY — answers live in the
/// per-user subcollection); the app resolves the question text from the
/// bundled pack by [packId] + [questionId]. The server assignment is
/// authoritative (ADR-011).
class CoupleDayAssignment {
  const CoupleDayAssignment({
    required this.questionId,
    required this.packId,
    required this.packVersion,
    this.assignedAt,
  });

  final String questionId;

  final String packId;

  /// The pack version the Function selected from; the bundled pack can lag
  /// it — `packId`+`questionId` are globally unique (validator-enforced), so
  /// text resolution needs no version juggling, but an id absent from the
  /// bundled pack is the honest "update the app" state.
  final int packVersion;

  /// Server stamp; null only in the (theoretical) pending window — the
  /// rollover writes with the admin SDK, so reads virtually always carry it.
  final DateTime? assignedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleDayAssignment &&
          other.questionId == questionId &&
          other.packId == packId &&
          other.packVersion == packVersion &&
          other.assignedAt == assignedAt;

  @override
  int get hashCode => Object.hash(questionId, packId, packVersion, assignedAt);

  @override
  String toString() =>
      'CoupleDayAssignment(questionId: $questionId, packId: $packId, '
      'packVersion: $packVersion, assignedAt: $assignedAt)';
}
