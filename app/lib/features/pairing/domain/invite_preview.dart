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
/// [creatorDisplayName] when the creator has one.
///
/// Designed to grow a `questionText` slot at M3 (the daily question shown on
/// the preview card) — kept OUT of the type until the server projects it, so
/// the leaked surface stays auditable in one place on both sides.
class InvitePreviewResult {
  const InvitePreviewResult({required this.status, this.creatorDisplayName});

  final InvitePreviewStatus status;

  /// The inviter's display name, present only alongside [InvitePreviewStatus
  /// .valid] and only when the server resolved one; null otherwise.
  final String? creatorDisplayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvitePreviewResult &&
          other.status == status &&
          other.creatorDisplayName == creatorDisplayName;

  @override
  int get hashCode => Object.hash(status, creatorDisplayName);

  @override
  String toString() =>
      'InvitePreviewResult(status: $status, '
      'creatorDisplayName: $creatorDisplayName)';
}
