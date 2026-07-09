import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' show OAuthCredential;
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/data/apple_auth_gateway.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  const rawNonce = 'raw-nonce-abc123';

  List<AppleIDAuthorizationScopes>? capturedScopes;
  String? capturedNonce;

  AuthorizationCredentialAppleID appleIdCredential({
    String? identityToken = 'apple-id-token',
    String? givenName = 'Aytek',
    String? familyName = 'Kara',
  }) => AuthorizationCredentialAppleID(
    userIdentifier: 'apple-user-1',
    givenName: givenName,
    familyName: familyName,
    authorizationCode: 'auth-code',
    email: 'a@example.com',
    identityToken: identityToken,
    state: null,
  );

  SignInWithAppleGateway gatewayReturning(
    AuthorizationCredentialAppleID credential,
  ) => SignInWithAppleGateway(
    generateRawNonce: () => rawNonce,
    getCredential: ({required scopes, nonce}) async {
      capturedScopes = scopes;
      capturedNonce = nonce;
      return credential;
    },
  );

  SignInWithAppleGateway gatewayThrowing(
    SignInWithAppleAuthorizationException error,
  ) => SignInWithAppleGateway(
    generateRawNonce: () => rawNonce,
    getCredential: ({required scopes, nonce}) async {
      capturedScopes = scopes;
      capturedNonce = nonce;
      throw error;
    },
  );

  setUp(() {
    capturedScopes = null;
    capturedNonce = null;
  });

  group('acquireCredential', () {
    test('returns an apple.com credential carrying the id token, raw nonce '
        'and full name', () async {
      final credential = await gatewayReturning(
        appleIdCredential(),
      ).acquireCredential();

      expect(credential, isA<OAuthCredential>());
      final oauth = credential! as OAuthCredential;
      expect(oauth.providerId, 'apple.com');
      expect(oauth.idToken, 'apple-id-token');
      expect(oauth.rawNonce, rawNonce);
      expect(oauth.appleFullPersonName?.givenName, 'Aytek');
      expect(oauth.appleFullPersonName?.familyName, 'Kara');
    });

    test('requests the email and fullName scopes', () async {
      await gatewayReturning(appleIdCredential()).acquireCredential();

      expect(capturedScopes, const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ]);
    });

    test('hands getAppleIDCredential the SHA-256 hex of the raw nonce that '
        'ends up on the credential (two-value nonce protocol)', () async {
      final oauth =
          (await gatewayReturning(appleIdCredential()).acquireCredential())!
              as OAuthCredential;

      final expectedHashed = sha256
          .convert(utf8.encode(oauth.rawNonce!))
          .toString();
      expect(capturedNonce, expectedHashed);
      // The hashed nonce goes to Apple; the PLAIN nonce goes to Firebase.
      expect(capturedNonce, isNot(oauth.rawNonce));
    });

    test('returns null when the user cancels the Apple sheet', () async {
      final gateway = gatewayThrowing(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'canceled',
        ),
      );

      expect(await gateway.acquireCredential(), isNull);
    });

    test(
      'maps non-cancel authorization codes to AuthUnknownException',
      () async {
        for (final code in [
          AuthorizationErrorCode.failed,
          AuthorizationErrorCode.invalidResponse,
          AuthorizationErrorCode.notHandled,
          AuthorizationErrorCode.unknown,
        ]) {
          final gateway = gatewayThrowing(
            SignInWithAppleAuthorizationException(code: code, message: 'boom'),
          );

          await expectLater(
            gateway.acquireCredential(),
            throwsA(AuthUnknownException(code: code.name, message: 'boom')),
          );
        }
      },
    );

    test(
      'throws missing-identity-token when Apple returns no identity token',
      () async {
        final gateway = gatewayReturning(
          appleIdCredential(identityToken: null),
        );

        await expectLater(
          gateway.acquireCredential(),
          throwsA(
            isA<AuthUnknownException>().having(
              (e) => e.code,
              'code',
              'missing-identity-token',
            ),
          ),
        );
      },
    );
  });
}
