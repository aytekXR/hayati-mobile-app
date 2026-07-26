/// Outcome of the zero-auth invite preview (`invitePreview`, M2.2). Deliberately
/// coarse: the server collapses a real 'joined'/malformed/past-expiry invite
/// all into [expired] so a preview leaks nothing about the invite's history.
///
/// - [valid]   — a live, pending invite the joiner can accept.
/// - [expired] — anything not currently joinable (expired, already joined, or
///               malformed). Uniform by design (see invite-preview.ts).
/// - [unknown] — no invite exists for the code (or the code was malformed).
enum InvitePreviewStatus { valid, expired, unknown }

/// The ENTIRE surface the preview exposes to the app — a mirror of the server's
/// `InvitePreview` projection (`functions/src/invites/invite-preview.ts`):
/// [status] plus, only for a [InvitePreviewStatus.valid] invite,
/// [creatorDisplayName] when the creator has one, and the PRD F1 question
/// hook (redesign ui-ux §5.3): [questionText] — today's question on the
/// inviter's side — with [creatorAnswered], whether they already answered it.
/// QUESTION TEXT ONLY, never answer content, on both sides by construction.
class InvitePreviewResult {
  const InvitePreviewResult({
    required this.status,
    this.creatorDisplayName,
    this.questionText,
    this.creatorAnswered = false,
  });

  final InvitePreviewStatus status;

  /// The inviter's display name, present only alongside [InvitePreviewStatus
  /// .valid] and only when the server resolved one; null otherwise.
  final String? creatorDisplayName;

  /// Today's question on the inviter's side (the PRD F1 hook), present only
  /// alongside [InvitePreviewStatus.valid] and only when the server resolved
  /// it; null otherwise. The server's honest bound: near the inviter's local
  /// midnight the fallback question can be one calendar day off their device
  /// view (documented in `creator-question.ts`).
  final String? questionText;

  /// Whether the inviter has already answered [questionText] — the sealed
  /// answer card's trigger ("{name} has already answered. Their answer
  /// unlocks when you write yours."). Meaningless without [questionText]
  /// (the parse keeps them coupled); defaults false.
  final bool creatorAnswered;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvitePreviewResult &&
          other.status == status &&
          other.creatorDisplayName == creatorDisplayName &&
          other.questionText == questionText &&
          other.creatorAnswered == creatorAnswered;

  @override
  int get hashCode =>
      Object.hash(status, creatorDisplayName, questionText, creatorAnswered);

  @override
  String toString() =>
      'InvitePreviewResult(status: $status, '
      'creatorDisplayName: $creatorDisplayName, '
      'questionText: $questionText, creatorAnswered: $creatorAnswered)';
}
