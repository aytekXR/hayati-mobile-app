/// Domain taxonomy for the invites callable family (issue + join, M2.1/M2.3)
/// plus the preview seam, mirroring `ProfileException`: the UI distinguishes
/// "retry might work" (network), "the session isn't authenticated" (permission
/// — a stale session or a client out of contract with the callable, never
/// user-recoverable) and "something else" (diagnostic code preserved). Joining
/// adds a set of user-meaningful, terminal precondition failures — each a
/// distinct member so the join screen can speak to it exactly (this code is
/// expired, that code was already used, you can't join your own invite, …).
/// The callable/HTTP boundaries translate their errors into exactly these;
/// anything else escaping is a bug.
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

/// The `joinInvite` code resolves to no invite (`not-found` / reason
/// `'unknown'`): a typo or a code that never existed. User-recoverable by
/// re-entering — the join screen prompts for the code again.
final class InviteJoinUnknownCodeException extends InviteException {
  const InviteJoinUnknownCodeException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteJoinUnknownCodeException && other.message == message;

  @override
  int get hashCode => Object.hash(InviteJoinUnknownCodeException, message);

  @override
  String toString() => 'InviteJoinUnknownCodeException(message: $message)';
}

/// The invite has expired (`failed-precondition` / reason `'expired'`): past
/// its TTL or explicitly expired. Terminal for this code — the creator must
/// issue a fresh one.
final class InviteJoinExpiredException extends InviteException {
  const InviteJoinExpiredException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteJoinExpiredException && other.message == message;

  @override
  int get hashCode => Object.hash(InviteJoinExpiredException, message);

  @override
  String toString() => 'InviteJoinExpiredException(message: $message)';
}

/// The invite was already joined by someone (`failed-precondition` / reason
/// `'consumed'`): a reused code or the losing side of a join race. Terminal.
final class InviteJoinConsumedException extends InviteException {
  const InviteJoinConsumedException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteJoinConsumedException && other.message == message;

  @override
  int get hashCode => Object.hash(InviteJoinConsumedException, message);

  @override
  String toString() => 'InviteJoinConsumedException(message: $message)';
}

/// The joiner is the invite's own creator (`failed-precondition` / reason
/// `'self-join'`): you cannot pair with yourself. Terminal for this code.
final class InviteJoinSelfJoinException extends InviteException {
  const InviteJoinSelfJoinException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteJoinSelfJoinException && other.message == message;

  @override
  int get hashCode => Object.hash(InviteJoinSelfJoinException, message);

  @override
  String toString() => 'InviteJoinSelfJoinException(message: $message)';
}

/// The joiner or the creator is already paired (`failed-precondition` / reason
/// `'already-paired'`): one of the two users already has a `coupleId`. Terminal
/// — Hayati pairs exactly two, once.
final class InviteJoinAlreadyPairedException extends InviteException {
  const InviteJoinAlreadyPairedException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteJoinAlreadyPairedException && other.message == message;

  @override
  int get hashCode => Object.hash(InviteJoinAlreadyPairedException, message);

  @override
  String toString() => 'InviteJoinAlreadyPairedException(message: $message)';
}

/// The joiner or the creator has no `users/{uid}` profile yet
/// (`failed-precondition` / reason `'profile-missing'`): onboarding must
/// complete before pairing. Recoverable by finishing profile capture.
final class InviteJoinProfileMissingException extends InviteException {
  const InviteJoinProfileMissingException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is InviteJoinProfileMissingException && other.message == message;

  @override
  int get hashCode => Object.hash(InviteJoinProfileMissingException, message);

  @override
  String toString() => 'InviteJoinProfileMissingException(message: $message)';
}
