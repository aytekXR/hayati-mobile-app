/// Domain taxonomy for profile persistence failures, mirroring
/// `AuthException`: the UI distinguishes "retry might work" (network),
/// "the rules said no" (permission — a bug or a stale session, never
/// user-recoverable) and "something else" (diagnostic code preserved).
/// Data-layer mappers translate Firestore exceptions into exactly these.
sealed class ProfileException implements Exception {
  const ProfileException();
}

/// Transient connectivity/availability failure — retrying is reasonable.
final class ProfileNetworkException extends ProfileException {
  const ProfileNetworkException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ProfileNetworkException && other.message == message;

  @override
  int get hashCode => Object.hash(ProfileNetworkException, message);

  @override
  String toString() => 'ProfileNetworkException(message: $message)';
}

/// Security rules rejected the operation (`permission-denied` /
/// `unauthenticated`): the session is stale or the client is out of contract
/// with `firestore.rules` — surfaced distinctly so it is never mistaken for
/// a connectivity blip.
final class ProfilePermissionException extends ProfileException {
  const ProfilePermissionException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ProfilePermissionException && other.message == message;

  @override
  int get hashCode => Object.hash(ProfilePermissionException, message);

  @override
  String toString() => 'ProfilePermissionException(message: $message)';
}

/// Anything else; [code] carries the raw provider code for diagnostics.
final class ProfileUnknownException extends ProfileException {
  const ProfileUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ProfileUnknownException &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() =>
      'ProfileUnknownException(code: $code, message: $message)';
}
