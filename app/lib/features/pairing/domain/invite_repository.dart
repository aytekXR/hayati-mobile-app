import 'invite_exception.dart';
import 'issued_invite.dart';

/// Contract for issuing the caller's shareable invite via the `createInvite`
/// callable (M2.1, `europe-west1`). Implementations map their errors into the
/// [InviteException] taxonomy; anything else escaping is a bug.
abstract interface class InviteRepository {
  /// Issues (or idempotently re-issues) the caller's one active invite. The
  /// server enforces the one-active-invite-per-creator policy, so calling
  /// twice within the TTL returns the same code with `reused: true`.
  Future<IssuedInvite> createInvite();
}
