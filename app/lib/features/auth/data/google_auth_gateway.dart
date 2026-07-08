import 'package:firebase_auth/firebase_auth.dart'
    show AuthCredential, GoogleAuthProvider;
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_exception.dart';

/// Seam between the Google identity flow and the Firebase credential step,
/// so the repository stays testable and the emulator integration test can
/// substitute a fake credential.
abstract interface class GoogleAuthGateway {
  /// Runs the interactive Google flow and returns the Firebase credential,
  /// or `null` when the user cancelled. Throws [AuthException] subtypes for
  /// every other failure.
  Future<AuthCredential?> acquireCredential();

  Future<void> signOut();
}

/// google_sign_in 7.x implementation.
///
/// v7 splits authentication (id token) from authorization (access tokens);
/// Firebase only needs the id token, so no authorization call is made.
class GoogleSignInAuthGateway implements GoogleAuthGateway {
  GoogleSignInAuthGateway({GoogleSignIn? signIn, this.serverClientId})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;

  /// Android needs the Firebase web/OAuth client id to mint a
  /// Firebase-verifiable id token; iOS reads its client id from the
  /// (M1.2-provisioned, issue #5) plist. Null until real config lands.
  final String? serverClientId;

  Future<void>? _initialization;

  /// google_sign_in 7.x contract: `initialize` must be called exactly once
  /// and completed before any other method — memoizing the future makes the
  /// call single-flight even under concurrent entry. A FAILED attempt is
  /// un-memoized so the UI's "Try again" can recover from a transient
  /// failure; failures are mapped into the domain taxonomy like every other
  /// error crossing this boundary.
  Future<void> _ensureInitialized() async {
    try {
      await (_initialization ??= _signIn.initialize(
        serverClientId: serverClientId,
      ));
    } on GoogleSignInException catch (failure) {
      _initialization = null;
      throw _mapGoogle(failure);
    } catch (failure) {
      _initialization = null;
      throw AuthUnknownException(
        code: 'initialization-failed',
        message: failure.toString(),
      );
    }
  }

  @override
  Future<AuthCredential?> acquireCredential() async {
    await _ensureInitialized();

    if (!_signIn.supportsAuthenticate()) {
      // Never true on iOS/Android; guards the web/desktop UnsupportedError.
      throw const AuthUnknownException(
        code: 'unsupported-platform',
        message: 'Interactive Google Sign-In is unavailable on this platform.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await _signIn.authenticate(scopeHint: const ['email']);
    } on GoogleSignInException catch (failure) {
      // v7 signals cancel by THROWING (never a null return) — translate it
      // back into this gateway's null contract.
      if (failure.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw _mapGoogle(failure);
    }

    // Synchronous getter in v7; the id token is all Firebase needs.
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthUnknownException(
        code: 'missing-id-token',
        message:
            'Google Sign-In returned no ID token '
            '(client id not configured?).',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    try {
      await _signIn.signOut();
    } on GoogleSignInException catch (failure) {
      throw _mapGoogle(failure);
    } catch (failure) {
      throw AuthUnknownException(
        code: 'sign-out-failed',
        message: failure.toString(),
      );
    }
  }

  /// Shared code mapping for non-cancel [GoogleSignInException]s: only
  /// clearly transient codes count as network; config problems keep their
  /// raw code for diagnostics.
  AuthException _mapGoogle(GoogleSignInException failure) =>
      switch (failure.code) {
        GoogleSignInExceptionCode.interrupted ||
        GoogleSignInExceptionCode.uiUnavailable => AuthNetworkException(
          message: failure.description,
        ),
        _ => AuthUnknownException(
          code: failure.code.name,
          message: failure.description,
        ),
      };
}
