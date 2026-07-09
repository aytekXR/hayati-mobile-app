/// Domain taxonomy for invite-issuing failures, mirroring `ProfileException`:
/// the UI distinguishes "retry might work" (network), "the session isn't
/// authenticated" (permission — a stale session or a client out of contract
/// with the callable, never user-recoverable) and "something else" (diagnostic
/// code preserved). The `createInvite` boundary translates
/// `FirebaseFunctionsException`s into exactly these; anything else escaping is
/// a bug.
sealed class InviteException implements Exception {
  const InviteException();
}

/// Transient connectivity/availability failure — retrying is reasonable.
final class InviteNetworkException extends InviteException {
  const InviteNetworkException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteNetworkException && other.message == message;

  @override
  int get hashCode => Object.hash(InviteNetworkException, message);

  @override
  String toString() => 'InviteNetworkException(message: $message)';
}

/// The callable rejected the caller as unauthenticated (`unauthenticated` /
/// `permission-denied`): the session is stale or missing — surfaced distinctly
/// so it is never mistaken for a connectivity blip.
final class InvitePermissionException extends InviteException {
  const InvitePermissionException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InvitePermissionException && other.message == message;

  @override
  int get hashCode => Object.hash(InvitePermissionException, message);

  @override
  String toString() => 'InvitePermissionException(message: $message)';
}

/// Anything else; [code] carries the raw callable code for diagnostics. The
/// server's `resource-exhausted` (the invite code space was momentarily full,
/// M2.1) lands here too: it is not a connectivity issue and not the user's
/// fault, so the generic "try again" copy is the honest surface.
final class InviteUnknownException extends InviteException {
  const InviteUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteUnknownException &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'InviteUnknownException(code: $code, message: $message)';
}
