import 'auth_exception.dart';
import 'auth_user.dart';

/// Domain contract for authentication. Implementations live in `data/`
/// (Firebase today); tests use `FakeAuthRepository` (test/support/).
///
/// All methods throw only [AuthException] subtypes — provider exceptions
/// must be mapped before they cross this boundary.
abstract interface class AuthRepository {
  /// Emits the signed-in user, or null when signed out. Fires on session
  /// restore, credential sign-in/out and external revocation.
  Stream<AuthUser?> authStateChanges();

  /// The synchronously-known current user (null when signed out).
  AuthUser? get currentUser;

  /// Runs the interactive Google flow through to a signed-in user.
  /// Throws [AuthCancelledException] when the user backs out.
  Future<AuthUser> signInWithGoogle();

  Future<void> signOut();
}
