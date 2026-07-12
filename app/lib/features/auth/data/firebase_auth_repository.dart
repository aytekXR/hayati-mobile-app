import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/phone_sign_in_session.dart';
import 'apple_auth_gateway.dart';
import 'google_auth_gateway.dart';
import 'phone_auth_gateway.dart';

/// Firebase-backed [AuthRepository]. Owns the User→AuthUser mapping and the
/// FirebaseAuthException→AuthException taxonomy — no Firebase type leaks
/// past this file into domain or presentation.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleAuthGateway googleGateway,
    required AppleAuthGateway appleGateway,
    required PhoneAuthGateway phoneGateway,
  }) : _auth = firebaseAuth,
       _google = googleGateway,
       _apple = appleGateway,
       _phone = phoneGateway;

  final FirebaseAuth _auth;
  final GoogleAuthGateway _google;
  final AppleAuthGateway _apple;
  final PhoneAuthGateway _phone;

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<AuthUser> signInWithGoogle() => _guarded(() async {
    // Gateway failures are already AuthException subtypes and pass through.
    final credential = await _google.acquireCredential();
    if (credential == null) {
      throw const AuthCancelledException();
    }
    final result = await _auth.signInWithCredential(credential);
    final user = _toAuthUser(result.user);
    if (user == null) {
      throw const AuthUnknownException(
        code: 'missing-user',
        message: 'Sign-in returned no user.',
      );
    }
    return user;
  });

  @override
  Future<AuthUser> signInWithApple() => _guarded(() async {
    // Gateway failures are already AuthException subtypes and pass through.
    final credential = await _apple.acquireCredential();
    if (credential == null) {
      throw const AuthCancelledException();
    }
    final result = await _auth.signInWithCredential(credential);
    final user = _toAuthUser(result.user);
    if (user == null) {
      throw const AuthUnknownException(
        code: 'missing-user',
        message: 'Sign-in returned no user.',
      );
    }
    return user;
  });

  @override
  Future<PhoneSignInSession> sendPhoneCode(
    String phoneNumber, {
    PhoneSignInSession? resendFrom,
  }) => _guarded(
    // The gateway already maps its FirebaseAuthExceptions to the taxonomy;
    // _guarded just passes those AuthException subtypes through.
    () => _phone.sendCode(phoneNumber, resendToken: resendFrom?.resendToken),
  );

  @override
  Future<AuthUser> confirmPhoneCode(
    PhoneSignInSession session,
    String smsCode,
  ) => _guarded(() async {
    // credentialFor is pure; the FirebaseAuthException from signInWithCredential
    // (invalid-verification-code / -id) is mapped by _mapFirebase below.
    final credential = _phone.credentialFor(session, smsCode);
    final result = await _auth.signInWithCredential(credential);
    final user = _toAuthUser(result.user);
    if (user == null) {
      throw const AuthUnknownException(
        code: 'missing-user',
        message: 'Sign-in returned no user.',
      );
    }
    return user;
  });

  @override
  Future<void> signOut() => _guarded(() async {
    // Google first: clears the account chooser so the next sign-in prompts,
    // then revoke the Firebase session.
    await _google.signOut();
    await _auth.signOut();
  });

  @override
  Future<void> signOutAfterAccountDeletion() => _guarded(() async {
    // Phase 2 of ADR-019 D7. The server cascade already deleted the Auth user;
    // this only clears the local session. The Google half is best-effort: a live
    // Google session for a deleted account is meaningless residue, and its
    // failure must NOT block the Firebase sign-out that lands AuthSignedOut and
    // fires the lock wipe. Only the Firebase sign-out's failure surfaces (as an
    // AuthException via _guarded), driving the phase-2 self-heal path.
    try {
      await _google.signOut();
    } catch (_) {
      // Swallowed by decision (ADR-019 D7 phase 2). Never a protection to keep.
    }
    await _auth.signOut();
  });

  /// Enforces the [AuthRepository] contract at the boundary: domain
  /// exceptions pass through, Firebase codes are mapped, and anything else
  /// (plugin `PlatformException`s, pigeon decode errors, …) is normalized —
  /// an unmapped throwable would slip past the controller's `on
  /// AuthException` and strand the UI on the signing-in spinner.
  Future<T> _guarded<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (failure) {
      throw _mapFirebase(failure);
    } catch (failure) {
      throw AuthUnknownException(
        code: 'unexpected-error',
        message: failure.toString(),
      );
    }
  }

  AuthUser? _toAuthUser(User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoURL,
        );

  AuthException _mapFirebase(FirebaseAuthException failure) =>
      switch (failure.code) {
        // The only code treated as transient/retryable.
        'network-request-failed' => AuthNetworkException(
          message: failure.message,
        ),
        // Phone confirm step: recoverable inline (re-enter the code).
        'invalid-verification-code' => const AuthInvalidCodeException(),
        // Phone confirm step: session dead, restart from phone entry.
        'invalid-verification-id' ||
        'session-expired' => const AuthSessionExpiredException(),
        _ => AuthUnknownException(code: failure.code, message: failure.message),
      };
}
