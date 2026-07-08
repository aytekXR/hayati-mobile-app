import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/data/firebase_auth_repository.dart';
import 'package:hayati_app/features/auth/data/google_auth_gateway.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class MockGoogleAuthGateway extends Mock implements GoogleAuthGateway {}

class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  late MockFirebaseAuth auth;
  late MockGoogleAuthGateway gateway;
  late FirebaseAuthRepository repository;

  final credential = GoogleAuthProvider.credential(idToken: 'id-token-1');

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
    repository = FirebaseAuthRepository(
      firebaseAuth: auth,
      googleGateway: gateway,
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
}
