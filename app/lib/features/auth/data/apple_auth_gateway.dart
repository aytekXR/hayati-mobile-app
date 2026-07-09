import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show AppleAuthProvider, AppleFullPersonName, AuthCredential;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/auth_exception.dart';

/// Function seam over [SignInWithApple.getAppleIDCredential]. SignInWithApple
/// is an all-static class with no instance to mock (brief-6-apple.md), so the
/// native call is injected as a function — unit tests stub it with no plugin
/// mock. Declares only the parameters this gateway passes; the tear-off keeps
/// its extra optional named parameters (webAuthenticationOptions, state).
typedef GetAppleIdCredential =
    Future<AuthorizationCredentialAppleID> Function({
      required List<AppleIDAuthorizationScopes> scopes,
      String? nonce,
    });

/// Seam between the native Sign in with Apple flow and the Firebase credential
/// step, mirroring [GoogleAuthGateway]. Deliberately exposes no `signOut`:
/// Apple keeps no client-side session to revoke (brief-6-apple.md), so
/// `repository.signOut` clears Google + Firebase only.
abstract interface class AppleAuthGateway {
  /// Runs the native Apple flow and returns the Firebase credential, or `null`
  /// when the user cancelled. Throws [AuthException] subtypes for every other
  /// failure.
  Future<AuthCredential?> acquireCredential();
}

/// sign_in_with_apple 8.x implementation.
///
/// Uses the native credential path (`credentialWithIDToken`), not
/// `signInWithProvider`: only a surfaced [AuthCredential] gives the repository
/// and the emulator a seam to drive (brief-6-apple.md).
class SignInWithAppleGateway implements AppleAuthGateway {
  SignInWithAppleGateway({
    GetAppleIdCredential? getCredential,
    String Function()? generateRawNonce,
  }) : _getCredential = getCredential ?? SignInWithApple.getAppleIDCredential,
       _generateRawNonce = generateRawNonce ?? generateNonce;

  final GetAppleIdCredential _getCredential;
  final String Function() _generateRawNonce;

  @override
  Future<AuthCredential?> acquireCredential() async {
    // Two-value nonce protocol (brief-6-apple.md): the SHA-256 hex of the raw
    // nonce is embedded in the identityToken via `nonce:`, while the PLAIN raw
    // nonce is handed to the credential so Firebase can re-hash and match the
    // token's nonce claim.
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await _getCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (failure) {
      // Apple signals cancel by throwing; translate it into this gateway's
      // null contract (mirrors the Google cancel path). The error enum carries
      // no transient/network code, so nothing maps to AuthNetworkException.
      if (failure.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw AuthUnknownException(
        code: failure.code.name,
        message: failure.message,
      );
    }

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw const AuthUnknownException(
        code: 'missing-identity-token',
        message: 'Sign in with Apple returned no identity token.',
      );
    }

    // givenName/familyName are populated only on the FIRST authorization;
    // forwarding them lets Firebase's asMap emit the name claims (Apple omits
    // them on re-auth, so later persistence is the app's responsibility).
    return AppleAuthProvider.credentialWithIDToken(
      identityToken,
      rawNonce,
      AppleFullPersonName(
        givenName: credential.givenName,
        familyName: credential.familyName,
      ),
    );
  }
}
