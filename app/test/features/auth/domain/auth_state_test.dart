import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_state.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';

void main() {
  const user = AuthUser(uid: 'uid-1');
  const other = AuthUser(uid: 'uid-2');

  group('AuthState equality', () {
    // Value equality is load-bearing: Riverpod's updateShouldNotify uses ==,
    // so equal states must not re-notify listeners.
    test('AuthSignedOut instances are equal', () {
      expect(const AuthSignedOut(), const AuthSignedOut());
      expect(const AuthSignedOut().hashCode, const AuthSignedOut().hashCode);
    });

    test('AuthSigningIn instances are equal', () {
      expect(const AuthSigningIn(), const AuthSigningIn());
    });

    test('AuthSignedIn equality follows the user', () {
      expect(const AuthSignedIn(user), const AuthSignedIn(user));
      expect(const AuthSignedIn(user), isNot(const AuthSignedIn(other)));
    });

    test('AuthError equality follows the failure', () {
      expect(
        const AuthError(AuthNetworkException(message: 'offline')),
        const AuthError(AuthNetworkException(message: 'offline')),
      );
      expect(
        const AuthError(AuthNetworkException(message: 'offline')),
        isNot(const AuthError(AuthCancelledException())),
      );
    });

    test('states of different types are unequal', () {
      expect(const AuthSignedOut(), isNot(const AuthSigningIn()));
      expect(const AuthSigningIn(), isNot(const AuthSignedIn(user)));
      expect(
        const AuthSignedIn(user),
        isNot(const AuthError(AuthCancelledException())),
      );
    });
  });

  group('AuthState exhaustiveness', () {
    String describe(AuthState state) => switch (state) {
      AuthSignedOut() => 'signed-out',
      AuthSigningIn() => 'signing-in',
      AuthSignedIn() => 'signed-in',
      AuthError() => 'error',
    };

    test('sealed switch covers every state', () {
      expect(describe(const AuthSignedOut()), 'signed-out');
      expect(describe(const AuthSigningIn()), 'signing-in');
      expect(describe(const AuthSignedIn(user)), 'signed-in');
      expect(describe(const AuthError(AuthCancelledException())), 'error');
    });

    test('AuthSignedIn exposes its user', () {
      expect(const AuthSignedIn(user).user, user);
    });

    test('AuthError exposes its failure', () {
      expect(
        const AuthError(AuthCancelledException()).failure,
        const AuthCancelledException(),
      );
    });
  });
}
