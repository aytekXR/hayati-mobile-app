import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'google_auth_gateway.dart';

/// Firebase-backed [AuthRepository]. Owns the User→AuthUser mapping and the
/// FirebaseAuthException→AuthException taxonomy — no Firebase type leaks
/// past this file into domain or presentation.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleAuthGateway googleGateway,
  }) : _auth = firebaseAuth,
       _google = googleGateway;

  final FirebaseAuth _auth;
  final GoogleAuthGateway _google;

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
  Future<void> signOut() => _guarded(() async {
    // Google first: clears the account chooser so the next sign-in prompts,
    // then revoke the Firebase session.
    await _google.signOut();
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
        _ => AuthUnknownException(code: failure.code, message: failure.message),
      };
}
