import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_state.dart';

void main() {
  const session = PhoneSignInSession('vid-1', resendToken: 3);
  const other = PhoneSignInSession('vid-2');

  group('PhoneSignInState equality', () {
    // Value equality is load-bearing: Riverpod's updateShouldNotify uses ==,
    // so re-emitting an equal state must not re-notify listeners.
    test('PhoneEntry instances are equal', () {
      expect(const PhoneEntry(), const PhoneEntry());
      expect(const PhoneEntry().hashCode, const PhoneEntry().hashCode);
    });

    test('PhoneSending instances are equal', () {
      expect(const PhoneSending(), const PhoneSending());
    });

    test('PhoneCodeSent equality follows session and resending', () {
      expect(const PhoneCodeSent(session), const PhoneCodeSent(session));
      expect(const PhoneCodeSent(session), isNot(const PhoneCodeSent(other)));
      expect(
        const PhoneCodeSent(session),
        isNot(const PhoneCodeSent(session, resending: true)),
      );
    });

    test('PhoneCodeSent.resending defaults to false', () {
      expect(const PhoneCodeSent(session).resending, isFalse);
    });

    test('PhoneConfirming equality follows session', () {
      expect(const PhoneConfirming(session), const PhoneConfirming(session));
      expect(
        const PhoneConfirming(session),
        isNot(const PhoneConfirming(other)),
      );
    });

    test('PhoneSignInFailure equality follows failure and session', () {
      expect(
        const PhoneSignInFailure(AuthInvalidCodeException(), session: session),
        const PhoneSignInFailure(AuthInvalidCodeException(), session: session),
      );
      expect(
        const PhoneSignInFailure(AuthInvalidCodeException(), session: session),
        isNot(const PhoneSignInFailure(AuthInvalidCodeException())),
      );
      expect(
        const PhoneSignInFailure(AuthInvalidCodeException()),
        isNot(const PhoneSignInFailure(AuthSessionExpiredException())),
      );
    });

    test('PhoneSignInFailure.session defaults to null', () {
      expect(
        const PhoneSignInFailure(AuthSessionExpiredException()).session,
        isNull,
      );
    });

    test('states of different types are unequal', () {
      expect(const PhoneEntry(), isNot(const PhoneSending()));
      expect(const PhoneSending(), isNot(const PhoneCodeSent(session)));
      expect(
        const PhoneCodeSent(session),
        isNot(const PhoneConfirming(session)),
      );
    });
  });

  group('PhoneSignInState exhaustiveness', () {
    String describe(PhoneSignInState state) => switch (state) {
      PhoneEntry() => 'entry',
      PhoneSending() => 'sending',
      PhoneCodeSent() => 'code-sent',
      PhoneConfirming() => 'confirming',
      PhoneSignInFailure() => 'failure',
    };

    test('sealed switch covers every state', () {
      expect(describe(const PhoneEntry()), 'entry');
      expect(describe(const PhoneSending()), 'sending');
      expect(describe(const PhoneCodeSent(session)), 'code-sent');
      expect(describe(const PhoneConfirming(session)), 'confirming');
      expect(
        describe(const PhoneSignInFailure(AuthInvalidCodeException())),
        'failure',
      );
    });

    test('PhoneCodeSent exposes its session and resending flag', () {
      const state = PhoneCodeSent(session, resending: true);
      expect(state.session, session);
      expect(state.resending, isTrue);
    });

    test('PhoneSignInFailure exposes its failure and session', () {
      const state = PhoneSignInFailure(
        AuthInvalidCodeException(),
        session: session,
      );
      expect(state.failure, const AuthInvalidCodeException());
      expect(state.session, session);
    });
  });
}
