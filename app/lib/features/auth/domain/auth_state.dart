import 'auth_exception.dart';
import 'auth_user.dart';

/// The auth state machine's states: signed-out → signing-in → signed-in,
/// with error as the failure terminal (docs/resume-prompt.md M1.1).
///
/// Value equality is load-bearing: Riverpod's `updateShouldNotify` uses `==`,
/// so re-emitting an equal state must not re-notify listeners.
sealed class AuthState {
  const AuthState();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut();

  @override
  bool operator ==(Object other) => other is AuthSignedOut;

  @override
  int get hashCode => (AuthSignedOut).hashCode;
}

final class AuthSigningIn extends AuthState {
  const AuthSigningIn();

  @override
  bool operator ==(Object other) => other is AuthSigningIn;

  @override
  int get hashCode => (AuthSigningIn).hashCode;
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AuthUser user;

  @override
  bool operator ==(Object other) => other is AuthSignedIn && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

final class AuthError extends AuthState {
  const AuthError(this.failure);

  final AuthException failure;

  @override
  bool operator ==(Object other) =>
      other is AuthError && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
