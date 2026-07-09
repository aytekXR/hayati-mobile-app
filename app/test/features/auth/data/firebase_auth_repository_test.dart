import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/data/apple_auth_gateway.dart';
import 'package:hayati_app/features/auth/data/firebase_auth_repository.dart';
import 'package:hayati_app/features/auth/data/google_auth_gateway.dart';
import 'package:hayati_app/features/auth/data/phone_auth_gateway.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class MockGoogleAuthGateway extends Mock implements GoogleAuthGateway {}

class MockAppleAuthGateway extends Mock implements AppleAuthGateway {}

class MockPhoneAuthGateway extends Mock implements PhoneAuthGateway {}

class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  late MockFirebaseAuth auth;
  late MockGoogleAuthGateway gateway;
  late MockAppleAuthGateway appleGateway;
  late MockPhoneAuthGateway phoneGateway;
  late FirebaseAuthRepository repository;

  final credential = GoogleAuthProvider.credential(idToken: 'id-token-1');
  final appleCredential = AppleAuthProvider.credentialWithIDToken(
    'apple-id-token',
    'raw-nonce',
    AppleFullPersonName(givenName: 'Aytek', familyName: 'Kara'),
  );

  MockUser makeUser({
    String uid = 'uid-1',
    String? displayName = 'Aytek',
    String? email = 'a@example.com',
    String? photoURL = 'https://example.com/p.png',
  }) {
    final user = MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => user.displayName).thenReturn(displayName);
    when(() => user.email).thenReturn(email);
    when(() => user.photoURL).thenReturn(photoURL);
    return user;
  }

  const expectedUser = AuthUser(
    uid: 'uid-1',
    displayName: 'Aytek',
    email: 'a@example.com',
    photoUrl: 'https://example.com/p.png',
  );

  setUp(() {
    auth = MockFirebaseAuth();
    gateway = MockGoogleAuthGateway();
    appleGateway = MockAppleAuthGateway();
    phoneGateway = MockPhoneAuthGateway();
    repository = FirebaseAuthRepository(
      firebaseAuth: auth,
      googleGateway: gateway,
      appleGateway: appleGateway,
      phoneGateway: phoneGateway,
    );
  });

  group('authStateChanges', () {
    test('maps Firebase users and passes null through', () {
      final user = makeUser();
      when(
        auth.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.fromIterable([user, null]));

      expect(
        repository.authStateChanges(),
        emitsInOrder(<Object?>[expectedUser, null, emitsDone]),
      );
    });
  });

  group('currentUser', () {
    test('maps the signed-in Firebase user', () {
      final user = makeUser();
      when(() => auth.currentUser).thenReturn(user);
      expect(repository.currentUser, expectedUser);
    });

    test('is null when signed out', () {
      when(() => auth.currentUser).thenReturn(null);
      expect(repository.currentUser, isNull);
    });
  });

  group('signInWithGoogle', () {
    test('signs in with the acquired credential and maps the user', () async {
      final user = makeUser();
      final userCredential = MockUserCredential();
      when(() => userCredential.user).thenReturn(user);
      when(
        () => gateway.acquireCredential(),
      ).thenAnswer((_) async => credential);
      when(
        () => auth.signInWithCredential(credential),
      ).thenAnswer((_) async => userCredential);

      expect(await repository.signInWithGoogle(), expectedUser);
      verify(() => auth.signInWithCredential(credential)).called(1);
    });

    test('throws AuthCancelledException without touching Firebase '
        'when the gateway reports cancellation', () async {
      when(() => gateway.acquireCredential()).thenAnswer((_) async => null);

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(const AuthCancelledException()),
      );
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('maps network-request-failed to AuthNetworkException', () async {
      when(
        () => gateway.acquireCredential(),
      ).thenAnswer((_) async => credential);
      when(() => auth.signInWithCredential(credential)).thenThrow(
        FirebaseAuthException(code: 'network-request-failed', message: 'off'),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(const AuthNetworkException(message: 'off')),
      );
    });

    test('preserves unknown Firebase codes for diagnostics', () async {
      when(
        () => gateway.acquireCredential(),
      ).thenAnswer((_) async => credential);
      when(() => auth.signInWithCredential(credential)).thenThrow(
        FirebaseAuthException(code: 'invalid-credential', message: 'bad'),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          const AuthUnknownException(
            code: 'invalid-credential',
            message: 'bad',
          ),
        ),
      );
    });

    test('treats a credential result without a user as unknown', () async {
      final userCredential = MockUserCredential();
      when(() => userCredential.user).thenReturn(null);
      when(
        () => gateway.acquireCredential(),
      ).thenAnswer((_) async => credential);
      when(
        () => auth.signInWithCredential(credential),
      ).thenAnswer((_) async => userCredential);

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthUnknownException>()),
      );
    });

    test('propagates gateway domain exceptions unchanged', () async {
      when(
        () => gateway.acquireCredential(),
      ).thenThrow(const AuthNetworkException(message: 'flaky'));

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(const AuthNetworkException(message: 'flaky')),
      );
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('normalizes non-Firebase plugin errors to AuthUnknownException '
        'instead of leaking them', () async {
      when(
        () => gateway.acquireCredential(),
      ).thenAnswer((_) async => credential);
      when(
        () => auth.signInWithCredential(credential),
      ).thenThrow(StateError('pigeon decode failure'));

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthUnknownException>().having(
            (e) => e.message,
            'message',
            contains('pigeon decode failure'),
          ),
        ),
      );
    });
  });

  group('signInWithApple', () {
    test('signs in with the acquired credential and maps the user', () async {
      final user = makeUser();
      final userCredential = MockUserCredential();
      when(() => userCredential.user).thenReturn(user);
      when(
        () => appleGateway.acquireCredential(),
      ).thenAnswer((_) async => appleCredential);
      when(
        () => auth.signInWithCredential(appleCredential),
      ).thenAnswer((_) async => userCredential);

      expect(await repository.signInWithApple(), expectedUser);
      verify(() => auth.signInWithCredential(appleCredential)).called(1);
    });

    test('throws AuthCancelledException without touching Firebase '
        'when the gateway reports cancellation', () async {
      when(
        () => appleGateway.acquireCredential(),
      ).thenAnswer((_) async => null);

      await expectLater(
        repository.signInWithApple(),
        throwsA(const AuthCancelledException()),
      );
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('maps network-request-failed to AuthNetworkException', () async {
      when(
        () => appleGateway.acquireCredential(),
      ).thenAnswer((_) async => appleCredential);
      when(() => auth.signInWithCredential(appleCredential)).thenThrow(
        FirebaseAuthException(code: 'network-request-failed', message: 'off'),
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(const AuthNetworkException(message: 'off')),
      );
    });

    test('preserves unknown Firebase codes for diagnostics', () async {
      when(
        () => appleGateway.acquireCredential(),
      ).thenAnswer((_) async => appleCredential);
      when(() => auth.signInWithCredential(appleCredential)).thenThrow(
        FirebaseAuthException(code: 'invalid-credential', message: 'bad'),
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          const AuthUnknownException(
            code: 'invalid-credential',
            message: 'bad',
          ),
        ),
      );
    });

    test('treats a credential result without a user as unknown', () async {
      final userCredential = MockUserCredential();
      when(() => userCredential.user).thenReturn(null);
      when(
        () => appleGateway.acquireCredential(),
      ).thenAnswer((_) async => appleCredential);
      when(
        () => auth.signInWithCredential(appleCredential),
      ).thenAnswer((_) async => userCredential);

      await expectLater(
        repository.signInWithApple(),
        throwsA(isA<AuthUnknownException>()),
      );
    });

    test('propagates gateway domain exceptions unchanged', () async {
      when(
        () => appleGateway.acquireCredential(),
      ).thenThrow(const AuthNetworkException(message: 'flaky'));

      await expectLater(
        repository.signInWithApple(),
        throwsA(const AuthNetworkException(message: 'flaky')),
      );
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('normalizes non-Firebase plugin errors to AuthUnknownException '
        'instead of leaking them', () async {
      when(
        () => appleGateway.acquireCredential(),
      ).thenAnswer((_) async => appleCredential);
      when(
        () => auth.signInWithCredential(appleCredential),
      ).thenThrow(StateError('pigeon decode failure'));

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AuthUnknownException>().having(
            (e) => e.message,
            'message',
            contains('pigeon decode failure'),
          ),
        ),
      );
    });
  });

  group('signOut', () {
    test('signs out of Google before Firebase', () async {
      when(() => gateway.signOut()).thenAnswer((_) async {});
      when(auth.signOut).thenAnswer((_) async {});

      await repository.signOut();

      verifyInOrder([gateway.signOut, auth.signOut]);
    });

    test(
      'maps FirebaseAuthException failures into the domain taxonomy',
      () async {
        when(() => gateway.signOut()).thenAnswer((_) async {});
        when(auth.signOut).thenThrow(
          FirebaseAuthException(code: 'network-request-failed', message: 'off'),
        );

        await expectLater(
          repository.signOut(),
          throwsA(const AuthNetworkException(message: 'off')),
        );
      },
    );

    test('propagates gateway domain exceptions unchanged', () async {
      when(
        () => gateway.signOut(),
      ).thenThrow(const AuthUnknownException(code: 'interrupted'));

      await expectLater(
        repository.signOut(),
        throwsA(const AuthUnknownException(code: 'interrupted')),
      );
    });

    test(
      'normalizes unexpected signOut failures to AuthUnknownException',
      () async {
        when(() => gateway.signOut()).thenAnswer((_) async {});
        when(auth.signOut).thenThrow(StateError('boom'));

        await expectLater(
          repository.signOut(),
          throwsA(isA<AuthUnknownException>()),
        );
      },
    );
  });

  group('sendPhoneCode', () {
    const session = PhoneSignInSession('vid-1', resendToken: 9);

    test('delegates to the gateway with a null resend token and '
        'returns the session', () async {
      when(
        () => phoneGateway.sendCode('+905551112233', resendToken: null),
      ).thenAnswer((_) async => session);

      expect(await repository.sendPhoneCode('+905551112233'), session);
      verify(
        () => phoneGateway.sendCode('+905551112233', resendToken: null),
      ).called(1);
    });

    test('threads a resend session token back into the gateway', () async {
      when(
        () => phoneGateway.sendCode('+905551112233', resendToken: 9),
      ).thenAnswer((_) async => const PhoneSignInSession('vid-2'));

      await repository.sendPhoneCode('+905551112233', resendFrom: session);

      verify(
        () => phoneGateway.sendCode('+905551112233', resendToken: 9),
      ).called(1);
    });

    test('propagates gateway domain exceptions unchanged', () async {
      when(
        () => phoneGateway.sendCode(
          any(),
          resendToken: any(named: 'resendToken'),
        ),
      ).thenThrow(const AuthNetworkException(message: 'off'));

      await expectLater(
        repository.sendPhoneCode('+905551112233'),
        throwsA(const AuthNetworkException(message: 'off')),
      );
    });

    test(
      'normalizes non-domain gateway errors to AuthUnknownException',
      () async {
        when(
          () => phoneGateway.sendCode(
            any(),
            resendToken: any(named: 'resendToken'),
          ),
        ).thenThrow(StateError('boom'));

        await expectLater(
          repository.sendPhoneCode('+905551112233'),
          throwsA(isA<AuthUnknownException>()),
        );
      },
    );
  });

  group('confirmPhoneCode', () {
    const session = PhoneSignInSession('vid-1');
    final phoneCredential = PhoneAuthProvider.credential(
      verificationId: 'vid-1',
      smsCode: '123456',
    );

    test('builds the credential and signs in, mapping the user', () async {
      final user = makeUser();
      final userCredential = MockUserCredential();
      when(() => userCredential.user).thenReturn(user);
      when(
        () => phoneGateway.credentialFor(session, '123456'),
      ).thenReturn(phoneCredential);
      when(
        () => auth.signInWithCredential(phoneCredential),
      ).thenAnswer((_) async => userCredential);

      expect(
        await repository.confirmPhoneCode(session, '123456'),
        expectedUser,
      );
      verify(() => auth.signInWithCredential(phoneCredential)).called(1);
    });

    test(
      'maps invalid-verification-code to AuthInvalidCodeException',
      () async {
        when(
          () => phoneGateway.credentialFor(session, '000000'),
        ).thenReturn(phoneCredential);
        when(
          () => auth.signInWithCredential(phoneCredential),
        ).thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

        await expectLater(
          repository.confirmPhoneCode(session, '000000'),
          throwsA(const AuthInvalidCodeException()),
        );
      },
    );

    test(
      'maps invalid-verification-id to AuthSessionExpiredException',
      () async {
        when(
          () => phoneGateway.credentialFor(session, '123456'),
        ).thenReturn(phoneCredential);
        when(
          () => auth.signInWithCredential(phoneCredential),
        ).thenThrow(FirebaseAuthException(code: 'invalid-verification-id'));

        await expectLater(
          repository.confirmPhoneCode(session, '123456'),
          throwsA(const AuthSessionExpiredException()),
        );
      },
    );

    test('maps session-expired to AuthSessionExpiredException', () async {
      when(
        () => phoneGateway.credentialFor(session, '123456'),
      ).thenReturn(phoneCredential);
      when(
        () => auth.signInWithCredential(phoneCredential),
      ).thenThrow(FirebaseAuthException(code: 'session-expired'));

      await expectLater(
        repository.confirmPhoneCode(session, '123456'),
        throwsA(const AuthSessionExpiredException()),
      );
    });

    test('preserves unknown Firebase codes for diagnostics', () async {
      when(
        () => phoneGateway.credentialFor(session, '123456'),
      ).thenReturn(phoneCredential);
      when(() => auth.signInWithCredential(phoneCredential)).thenThrow(
        FirebaseAuthException(code: 'too-many-requests', message: 'slow'),
      );

      await expectLater(
        repository.confirmPhoneCode(session, '123456'),
        throwsA(
          const AuthUnknownException(
            code: 'too-many-requests',
            message: 'slow',
          ),
        ),
      );
    });

    test('treats a credential result without a user as unknown', () async {
      final userCredential = MockUserCredential();
      when(() => userCredential.user).thenReturn(null);
      when(
        () => phoneGateway.credentialFor(session, '123456'),
      ).thenReturn(phoneCredential);
      when(
        () => auth.signInWithCredential(phoneCredential),
      ).thenAnswer((_) async => userCredential);

      await expectLater(
        repository.confirmPhoneCode(session, '123456'),
        throwsA(isA<AuthUnknownException>()),
      );
    });

    test(
      'normalizes non-Firebase plugin errors to AuthUnknownException',
      () async {
        when(
          () => phoneGateway.credentialFor(session, '123456'),
        ).thenReturn(phoneCredential);
        when(
          () => auth.signInWithCredential(phoneCredential),
        ).thenThrow(StateError('pigeon decode failure'));

        await expectLater(
          repository.confirmPhoneCode(session, '123456'),
          throwsA(
            isA<AuthUnknownException>().having(
              (e) => e.message,
              'message',
              contains('pigeon decode failure'),
            ),
          ),
        );
      },
    );
  });
}
