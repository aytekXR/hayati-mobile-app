import 'auth_exception.dart';
import 'auth_user.dart';
import 'phone_sign_in_session.dart';

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

  /// Runs the native Sign in with Apple flow through to a signed-in user.
  /// Throws [AuthCancelledException] when the user backs out; every other
  /// failure follows the shared taxonomy. Throws only [AuthException] subtypes.
  Future<AuthUser> signInWithApple();

  /// Sends an SMS verification code to [phoneNumber] and returns an opaque
  /// [PhoneSignInSession] to confirm against. Pass [resendFrom] to force a
  /// resend reusing the prior session's resend token. No E.164 validation
  /// beyond trimming happens here — the backend/emulator's own validation
  /// surfaces as [AuthException] subtypes (brief-3.md: sign-in only, no client
  /// validation). Throws only [AuthException] subtypes.
  Future<PhoneSignInSession> sendPhoneCode(
    String phoneNumber, {
    PhoneSignInSession? resendFrom,
  });

  /// Confirms [smsCode] against [session] and returns the signed-in user.
  /// Throws [AuthInvalidCodeException] for a wrong code (recoverable inline)
  /// and [AuthSessionExpiredException] for a stale session (restart the flow);
  /// other failures follow the shared taxonomy. Throws only [AuthException].
  Future<AuthUser> confirmPhoneCode(PhoneSignInSession session, String smsCode);

  Future<void> signOut();
}
