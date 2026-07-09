import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';

void main() {
  group('PhoneSignInSession', () {
    // Value equality is load-bearing: the session is threaded through
    // PhoneSignInState, and Riverpod's updateShouldNotify uses ==.
    test('equality follows verificationId and resendToken', () {
      expect(
        const PhoneSignInSession('vid-1', resendToken: 7),
        const PhoneSignInSession('vid-1', resendToken: 7),
      );
      expect(
        const PhoneSignInSession('vid-1', resendToken: 7).hashCode,
        const PhoneSignInSession('vid-1', resendToken: 7).hashCode,
      );
    });

    test('differs on verificationId', () {
      expect(
        const PhoneSignInSession('vid-1'),
        isNot(const PhoneSignInSession('vid-2')),
      );
    });

    test('differs on resendToken', () {
      expect(
        const PhoneSignInSession('vid-1', resendToken: 7),
        isNot(const PhoneSignInSession('vid-1', resendToken: 8)),
      );
      expect(
        const PhoneSignInSession('vid-1'),
        isNot(const PhoneSignInSession('vid-1', resendToken: 0)),
      );
    });

    test('resendToken defaults to null', () {
      expect(const PhoneSignInSession('vid-1').resendToken, isNull);
    });

    test('exposes its fields', () {
      const session = PhoneSignInSession('vid-9', resendToken: 42);
      expect(session.verificationId, 'vid-9');
      expect(session.resendToken, 42);
    });

    test('toString carries diagnostic fields', () {
      expect(
        const PhoneSignInSession('vid-9', resendToken: 42).toString(),
        allOf(contains('vid-9'), contains('42')),
      );
    });
  });
}
