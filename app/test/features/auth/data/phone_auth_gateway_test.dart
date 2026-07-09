import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/data/phone_auth_gateway.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  setUpAll(() {
    // verifyPhoneNumber's callback parameters are non-nullable typedefs, so
    // mocktail needs fallbacks to match them with any(named:).
    registerFallbackValue((PhoneAuthCredential _) {});
    registerFallbackValue((FirebaseAuthException _) {});
    registerFallbackValue((String _, int? _) {});
    registerFallbackValue((String _) {});
  });

  late MockFirebaseAuth auth;
  late FirebaseVerifyPhoneGateway gateway;

  // Callbacks Firebase would invoke, captured so each test drives the flow.
  late void Function(String verificationId, int? token) codeSent;
  late void Function(FirebaseAuthException error) verificationFailed;
  late void Function(String verificationId) autoRetrievalTimeout;
  late void Function(PhoneAuthCredential credential) verificationCompleted;

  // Controls the Future returned by verifyPhoneNumber (the pigeon/native call
  // itself can reject independently of the callbacks). Null => resolves.
  Completer<void>? verifyResult;

  void stubVerify() {
    when(
      () => auth.verifyPhoneNumber(
        phoneNumber: any(named: 'phoneNumber'),
        forceResendingToken: any(named: 'forceResendingToken'),
        verificationCompleted: any(named: 'verificationCompleted'),
        verificationFailed: any(named: 'verificationFailed'),
        codeSent: any(named: 'codeSent'),
        codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
      ),
    ).thenAnswer((invocation) {
      codeSent =
          invocation.namedArguments[#codeSent] as void Function(String, int?);
      verificationFailed =
          invocation.namedArguments[#verificationFailed]
              as void Function(FirebaseAuthException);
      autoRetrievalTimeout =
          invocation.namedArguments[#codeAutoRetrievalTimeout]
              as void Function(String);
      verificationCompleted =
          invocation.namedArguments[#verificationCompleted]
              as void Function(PhoneAuthCredential);
      return verifyResult?.future ?? Future<void>.value();
    });
  }

  setUp(() {
    auth = MockFirebaseAuth();
    gateway = FirebaseVerifyPhoneGateway(auth);
    verifyResult = null;
  });

  group('sendCode', () {
    test('completes with the session when codeSent fires', () async {
      stubVerify();
      final future = gateway.sendCode('+905551112233');
      codeSent('vid-1', 42);

      expect(await future, const PhoneSignInSession('vid-1', resendToken: 42));
    });

    test('forwards the resend token to verifyPhoneNumber', () async {
      stubVerify();
      final future = gateway.sendCode('+905551112233', resendToken: 7);
      codeSent('vid-1', null);
      await future;

      verify(
        () => auth.verifyPhoneNumber(
          phoneNumber: '+905551112233',
          forceResendingToken: 7,
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        ),
      ).called(1);
    });

    test('errors when verificationFailed fires before codeSent', () async {
      stubVerify();
      final future = gateway.sendCode('+905551112233');
      verificationFailed(
        FirebaseAuthException(code: 'too-many-requests', message: 'slow down'),
      );

      await expectLater(
        future,
        throwsA(
          const AuthUnknownException(
            code: 'too-many-requests',
            message: 'slow down',
          ),
        ),
      );
    });

    test('fails loudly when Android instant verification fires '
        'verificationCompleted instead of codeSent (issue #13)', () async {
      stubVerify();
      final future = gateway.sendCode('+905551112233');
      // Android-only: codeSent never arrives, so an ignored callback would
      // leave sendCode pending forever.
      verificationCompleted(
        PhoneAuthProvider.credential(verificationId: 'vid-1', smsCode: '1234'),
      );

      await expectLater(
        future,
        throwsA(
          isA<AuthUnknownException>().having(
            (e) => e.code,
            'code',
            'auto-resolution-unsupported',
          ),
        ),
      );
    });

    test('ignores verificationCompleted arriving after codeSent '
        '(Android auto-retrieval; no double-completion crash)', () async {
      stubVerify();
      final future = gateway.sendCode('+905551112233');
      codeSent('vid-1', null);
      expect(await future, const PhoneSignInSession('vid-1'));

      expect(
        () => verificationCompleted(
          PhoneAuthProvider.credential(
            verificationId: 'vid-1',
            smsCode: '1234',
          ),
        ),
        returnsNormally,
      );
    });

    test('maps a network verificationFailed to AuthNetworkException', () async {
      stubVerify();
      final future = gateway.sendCode('+905551112233');
      verificationFailed(
        FirebaseAuthException(code: 'network-request-failed', message: 'off'),
      );

      await expectLater(
        future,
        throwsA(const AuthNetworkException(message: 'off')),
      );
    });

    test('ignores a late verificationFailed after codeSent has resolved '
        'the session (no double-completion crash)', () async {
      stubVerify();
      final future = gateway.sendCode('+905551112233');
      codeSent('vid-1', null);
      expect(await future, const PhoneSignInSession('vid-1'));

      // Both can fire on the same broadcast stream after codeSent; guarded
      // completions must swallow them rather than throw 'Future already
      // completed'.
      expect(
        () => verificationFailed(FirebaseAuthException(code: 'anything')),
        returnsNormally,
      );
      expect(() => autoRetrievalTimeout('vid-1'), returnsNormally);
    });

    test('maps a rejection of the returned verify Future', () async {
      verifyResult = Completer<void>();
      stubVerify();
      final future = gateway.sendCode('+905551112233');
      verifyResult!.completeError(
        FirebaseAuthException(code: 'invalid-phone-number', message: 'bad'),
      );

      await expectLater(
        future,
        throwsA(
          const AuthUnknownException(
            code: 'invalid-phone-number',
            message: 'bad',
          ),
        ),
      );
    });

    test('rejects (does not throw synchronously) when verifyPhoneNumber '
        'throws synchronously', () async {
      when(
        () => auth.verifyPhoneNumber(
          phoneNumber: any(named: 'phoneNumber'),
          forceResendingToken: any(named: 'forceResendingToken'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        ),
      ).thenThrow(StateError('pigeon boom'));

      await expectLater(
        gateway.sendCode('+905551112233'),
        throwsA(
          isA<AuthUnknownException>().having(
            (e) => e.message,
            'message',
            contains('pigeon boom'),
          ),
        ),
      );
    });
  });

  group('credentialFor', () {
    test('builds a PhoneAuthCredential from the session and code', () {
      final credential = gateway.credentialFor(
        const PhoneSignInSession('vid-9'),
        '123456',
      );

      expect(credential, isA<PhoneAuthCredential>());
      final phone = credential as PhoneAuthCredential;
      expect(phone.verificationId, 'vid-9');
      expect(phone.smsCode, '123456');
    });
  });
}
