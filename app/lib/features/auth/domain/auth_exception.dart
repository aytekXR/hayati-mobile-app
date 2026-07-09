/// Domain taxonomy for auth failures. Deliberately small: the UI only needs
/// to distinguish "user backed out" (no error surface), "retry might work"
/// (network) and "something else" (diagnostic code preserved for copy/logs).
/// Data-layer mappers translate provider exceptions into exactly these.
sealed class AuthException implements Exception {
  const AuthException();
}

/// The user aborted the provider flow (e.g. dismissed the Google sheet).
final class AuthCancelledException extends AuthException {
  const AuthCancelledException();

  @override
  bool operator ==(Object other) => other is AuthCancelledException;

  @override
  int get hashCode => (AuthCancelledException).hashCode;

  @override
  String toString() => 'AuthCancelledException()';
}

/// A transient connectivity failure — retrying is a reasonable suggestion.
final class AuthNetworkException extends AuthException {
  const AuthNetworkException({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is AuthNetworkException && other.message == message;

  @override
  int get hashCode => Object.hash(AuthNetworkException, message);

  @override
  String toString() => 'AuthNetworkException(message: $message)';
}

/// The SMS code the user entered does not match the one sent
/// ('invalid-verification-code'). Recoverable inline: the confirm screen keeps
/// the session and lets the user re-enter the code (brief-3.md DESIGN).
final class AuthInvalidCodeException extends AuthException {
  const AuthInvalidCodeException();

  @override
  bool operator ==(Object other) => other is AuthInvalidCodeException;

  @override
  int get hashCode => (AuthInvalidCodeException).hashCode;

  @override
  String toString() => 'AuthInvalidCodeException()';
}

/// The verification session is no longer usable ('invalid-verification-id' or
/// 'session-expired'): the session must be discarded and the user sent back to
/// re-enter their phone number (brief-3.md DESIGN).
final class AuthSessionExpiredException extends AuthException {
  const AuthSessionExpiredException();

  @override
  bool operator ==(Object other) => other is AuthSessionExpiredException;

  @override
  int get hashCode => (AuthSessionExpiredException).hashCode;

  @override
  String toString() => 'AuthSessionExpiredException()';
}

/// Anything else; [code] carries the raw provider code for diagnostics.
final class AuthUnknownException extends AuthException {
  const AuthUnknownException({this.code, this.message});

  final String? code;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is AuthUnknownException &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'AuthUnknownException(code: $code, message: $message)';
}
