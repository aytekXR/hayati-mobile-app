import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';

void main() {
  group('AuthException', () {
    test('AuthCancelledException instances are equal', () {
      expect(const AuthCancelledException(), const AuthCancelledException());
    });

    test('AuthNetworkException equality follows the message', () {
      expect(
        const AuthNetworkException(message: 'offline'),
        const AuthNetworkException(message: 'offline'),
      );
      expect(
        const AuthNetworkException(message: 'offline'),
        isNot(const AuthNetworkException(message: 'timeout')),
      );
    });

    test('AuthUnknownException equality follows code and message', () {
      expect(
        const AuthUnknownException(code: 'invalid-credential', message: 'm'),
        const AuthUnknownException(code: 'invalid-credential', message: 'm'),
      );
      expect(
        const AuthUnknownException(code: 'invalid-credential'),
        isNot(const AuthUnknownException(code: 'user-disabled')),
      );
    });

    test('AuthInvalidCodeException instances are equal', () {
      expect(
        const AuthInvalidCodeException(),
        const AuthInvalidCodeException(),
      );
      expect(
        const AuthInvalidCodeException().hashCode,
        const AuthInvalidCodeException().hashCode,
      );
    });

    test('AuthSessionExpiredException instances are equal', () {
      expect(
        const AuthSessionExpiredException(),
        const AuthSessionExpiredException(),
      );
    });

    test('subtypes of different types are unequal', () {
      expect(
        const AuthCancelledException(),
        isNot(const AuthNetworkException()),
      );
      expect(
        const AuthInvalidCodeException(),
        isNot(const AuthSessionExpiredException()),
      );
    });

    test('toString carries diagnostic fields', () {
      expect(
        const AuthUnknownException(
          code: 'user-disabled',
          message: 'gone',
        ).toString(),
        allOf(contains('user-disabled'), contains('gone')),
      );
      expect(
        const AuthNetworkException(message: 'offline').toString(),
        contains('offline'),
      );
    });

    test('sealed switch covers every subtype', () {
      String describe(AuthException e) => switch (e) {
        AuthCancelledException() => 'cancelled',
        AuthNetworkException() => 'network',
        AuthInvalidCodeException() => 'invalid-code',
        AuthSessionExpiredException() => 'session-expired',
        AuthUnknownException() => 'unknown',
      };
      expect(describe(const AuthCancelledException()), 'cancelled');
      expect(describe(const AuthNetworkException()), 'network');
      expect(describe(const AuthInvalidCodeException()), 'invalid-code');
      expect(describe(const AuthSessionExpiredException()), 'session-expired');
      expect(describe(const AuthUnknownException()), 'unknown');
    });
  });
}
