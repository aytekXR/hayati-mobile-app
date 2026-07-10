import 'invite_exception.dart';
import 'issued_invite.dart';

/// Contract for the authenticated invites callable family — issue
/// (`createInvite`, M2.1) and join (`joinInvite`, M2.3), both `europe-west1`.
/// Implementations map their errors into the [InviteException] taxonomy;
/// anything else escaping is a bug. (The zero-auth preview is a separate seam,
/// [InvitePreviewRepository], because it is plain HTTP, not a callable.)
abstract interface class InviteRepository {
  /// Issues (or idempotently re-issues) the caller's one active invite. The
  /// server enforces the one-active-invite-per-creator policy, so calling
  /// twice within the TTL returns the same code with `reused: true`.
  Future<IssuedInvite> createInvite();

  /// Redeems [code] on behalf of the signed-in caller and returns the new (or
  /// existing) `couples/{coupleId}`. The server runs the whole pairing in one
  /// transaction; every rejection is a distinct [InviteException] member
  /// (unknown code, expired, consumed, self-join, already-paired,
  /// profile-missing) so the join screen can speak to each precisely.
  Future<String> joinInvite(String code);
}
