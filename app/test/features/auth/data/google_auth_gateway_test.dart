import 'package:firebase_auth/firebase_auth.dart' show OAuthCredential;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hayati_app/features/auth/data/google_auth_gateway.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late MockGoogleSignIn signIn;
  late GoogleSignInAuthGateway gateway;

  MockGoogleSignInAccount accountWithIdToken(String? idToken) {
    final account = MockGoogleSignInAccount();
    when(
      () => account.authentication,
    ).thenReturn(GoogleSignInAuthentication(idToken: idToken));
    return account;
  }

  void stubAuthenticate({
    GoogleSignInAccount? account,
    GoogleSignInException? failure,
  }) {
    final stub = when(
      () => signIn.authenticate(scopeHint: any(named: 'scopeHint')),
    );
    if (failure != null) {
      stub.thenThrow(failure);
    } else {
      stub.thenAnswer((_) async => account!);
    }
  }

  setUp(() {
    signIn = MockGoogleSignIn();
    gateway = GoogleSignInAuthGateway(signIn: signIn);
    when(
      () => signIn.initialize(
        clientId: any(named: 'clientId'),
        serverClientId: any(named: 'serverClientId'),
      ),
    ).thenAnswer((_) async {});
    when(signIn.supportsAuthenticate).thenReturn(true);
    when(signIn.signOut).thenAnswer((_) async {});
  });

  group('acquireCredential', () {
    test('returns a Google credential built from the id token', () async {
      stubAuthenticate(account: accountWithIdToken('id-token-1'));

      final credential = await gateway.acquireCredential();

      expect(credential, isA<OAuthCredential>());
      final oauth = credential! as OAuthCredential;
      expect(oauth.idToken, 'id-token-1');
      expect(oauth.providerId, 'google.com');
    });

    test('initializes google_sign_in exactly once across calls', () async {
      stubAuthenticate(account: accountWithIdToken('id-token-1'));

      await gateway.acquireCredential();
      await gateway.acquireCredential();

      verify(
        () => signIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
      ).called(1);
    });

    test('returns null when the user cancels the Google sheet', () async {
      stubAuthenticate(
        failure: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      );

      expect(await gateway.acquireCredential(), isNull);
    });

    test(
      'maps interrupted and uiUnavailable to AuthNetworkException',
      () async {
        for (final code in [
          GoogleSignInExceptionCode.interrupted,
          GoogleSignInExceptionCode.uiUnavailable,
        ]) {
          stubAuthenticate(
            failure: GoogleSignInException(code: code, description: 'flaky'),
          );
          await expectLater(
            gateway.acquireCredential(),
            throwsA(const AuthNetworkException(message: 'flaky')),
          );
        }
      },
    );

    test(
      'maps other GoogleSignInException codes to AuthUnknownException',
      () async {
        stubAuthenticate(
          failure: const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
            description: 'missing client id',
          ),
        );

        await expectLater(
          gateway.acquireCredential(),
          throwsA(
            const AuthUnknownException(
              code: 'clientConfigurationError',
              message: 'missing client id',
            ),
          ),
        );
      },
    );

    test('throws when the account carries no id token', () async {
      stubAuthenticate(account: accountWithIdToken(null));

      await expectLater(
        gateway.acquireCredential(),
        throwsA(isA<AuthUnknownException>()),
      );
    });

    test('fails fast when the platform cannot authenticate', () async {
      when(signIn.supportsAuthenticate).thenReturn(false);

      await expectLater(
        gateway.acquireCredential(),
        throwsA(isA<AuthUnknownException>()),
      );
      verifyNever(
        () => signIn.authenticate(scopeHint: any(named: 'scopeHint')),
      );
    });

    test('maps a GoogleSignInException from initialize into the domain '
        'taxonomy', () async {
      when(
        () => signIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
      ).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.providerConfigurationError,
          description: 'no play services',
        ),
      );

      await expectLater(
        gateway.acquireCredential(),
        throwsA(
          const AuthUnknownException(
            code: 'providerConfigurationError',
            message: 'no play services',
          ),
        ),
      );
    });

    test('maps a non-GoogleSignInException initialize failure to '
        'AuthUnknownException', () async {
      when(
        () => signIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
      ).thenThrow(StateError('channel not registered'));

      await expectLater(
        gateway.acquireCredential(),
        throwsA(
          isA<AuthUnknownException>().having(
            (e) => e.message,
            'message',
            contains('channel not registered'),
          ),
        ),
      );
    });

    test('retries initialization after a failed attempt', () async {
      var attempts = 0;
      when(
        () => signIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
      ).thenAnswer((_) {
        attempts++;
        if (attempts == 1) {
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
          );
        }
        return Future<void>.value();
      });
      stubAuthenticate(account: accountWithIdToken('id-token-1'));

      // First call fails on init; the failure must NOT be cached.
      await expectLater(
        gateway.acquireCredential(),
        throwsA(isA<AuthNetworkException>()),
      );
      // 'Try again' path: a fresh call re-initializes and succeeds.
      expect(await gateway.acquireCredential(), isNotNull);
      expect(attempts, 2);
    });
  });

  group('signOut', () {
    test('initializes then delegates to GoogleSignIn.signOut', () async {
      await gateway.signOut();

      verifyInOrder([
        () => signIn.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
        signIn.signOut,
      ]);
    });

    test(
      'maps GoogleSignInException failures into the domain taxonomy',
      () async {
        when(signIn.signOut).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
            description: 'flaky',
          ),
        );

        await expectLater(
          gateway.signOut(),
          throwsA(const AuthNetworkException(message: 'flaky')),
        );
      },
    );

    test('maps unexpected signOut failures to AuthUnknownException', () async {
      when(signIn.signOut).thenThrow(StateError('boom'));

      await expectLater(
        gateway.signOut(),
        throwsA(isA<AuthUnknownException>()),
      );
    });
  });
}
