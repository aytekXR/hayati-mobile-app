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
