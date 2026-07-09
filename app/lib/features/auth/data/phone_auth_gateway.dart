import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart'
    show AuthCredential, FirebaseAuth, FirebaseAuthException, PhoneAuthProvider;

import '../domain/auth_exception.dart';
import '../domain/phone_sign_in_session.dart';

/// Seam between Firebase's callback-driven `verifyPhoneNumber` and the
/// two-step, Future-returning repository flow, mirroring `GoogleAuthGateway`.
/// Keeps every Firebase phone type inside `data/` and stays VM-fakeable
/// (brief-3.md fileEdits; docs/architecture.md §2).
abstract interface class PhoneAuthGateway {
  /// Requests an SMS code for [phoneNumber] and completes with the opaque
  /// [PhoneSignInSession] once Firebase reports `codeSent`. Pass [resendToken]
  /// (from a prior session) to force a resend. No E.164 validation happens
  /// here — malformed numbers surface through the taxonomy (brief-3.md).
  /// Throws [AuthException] subtypes for every failure path.
  Future<PhoneSignInSession> sendCode(String phoneNumber, {int? resendToken});

  /// Builds the Firebase phone credential for [session] + [smsCode]. Pure
  /// construction; the sign-in itself happens in the repository so the
  /// FirebaseAuthException→taxonomy mapping stays at that boundary.
  AuthCredential credentialFor(PhoneSignInSession session, String smsCode);
}

/// `firebase_auth` implementation adapting the four `verifyPhoneNumber`
/// callbacks into a single [Future].
///
/// The returned `Future<void>` resolving does NOT signal success — completion
/// is delivered only through the callbacks (brief-3.md constraints). Two
/// independent error channels are funnelled into one [Completer]: the
/// `verificationFailed` callback and a rejection of the returned Future (the
/// pigeon/native call can throw). Every completion is guarded because
/// `verificationFailed` / `codeAutoRetrievalTimeout` can fire AFTER `codeSent`
/// on the same broadcast stream and double-completing a [Completer] throws.
class FirebaseVerifyPhoneGateway implements PhoneAuthGateway {
  FirebaseVerifyPhoneGateway(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<PhoneSignInSession> sendCode(String phoneNumber, {int? resendToken}) {
    final completer = Completer<PhoneSignInSession>();

    void succeed(PhoneSignInSession session) {
      if (!completer.isCompleted) completer.complete(session);
    }

    void fail(AuthException error, [StackTrace? stackTrace]) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    try {
      unawaited(
        _auth
            .verifyPhoneNumber(
              phoneNumber: phoneNumber,
              forceResendingToken: resendToken,
              // Android-only (types.dart:12): never fires on iOS, so the flow
              // is always driven manually there. On Android, instant
              // verification fires this INSTEAD of codeSent — dropping it would
              // leave the completer unresolved and hang sendCode forever. Fail
              // loudly instead. When it fires AFTER codeSent (auto-retrieval of
              // an already-sent code) the completer is already resolved and the
              // guard makes this a no-op.
              // DEBT: real Android support signs in with the auto-resolved
              // credential rather than erroring — issue #13, M6.5 (ADR-006).
              verificationCompleted: (_) => fail(
                const AuthUnknownException(
                  code: 'auto-resolution-unsupported',
                  message:
                      'Android instant verification is not supported yet '
                      '(issue #13).',
                ),
              ),
              verificationFailed: (failure) => fail(_mapFirebase(failure)),
              codeSent: (verificationId, forceResendingToken) => succeed(
                PhoneSignInSession(
                  verificationId,
                  resendToken: forceResendingToken,
                ),
              ),
              // On iOS there is no SMS auto-retrieval: this fires ~timeout
              // after codeSent with the same id and is benign — ignore it.
              codeAutoRetrievalTimeout: (_) {},
            )
            .catchError(
              (Object error, StackTrace stackTrace) =>
                  fail(_mapError(error), stackTrace),
            ),
      );
    } catch (error, stackTrace) {
      // A synchronous throw before the Future is even returned still lands as
      // a rejected sendCode Future, never a synchronous throw at this seam.
      fail(_mapError(error), stackTrace);
    }

    return completer.future;
  }

  @override
  AuthCredential credentialFor(PhoneSignInSession session, String smsCode) =>
      PhoneAuthProvider.credential(
        verificationId: session.verificationId,
        smsCode: smsCode,
      );

  /// Normalizes any throwable from the returned Future into the taxonomy;
  /// domain exceptions pass through unchanged.
  AuthException _mapError(Object error) => switch (error) {
    final AuthException e => e,
    final FirebaseAuthException e => _mapFirebase(e),
    _ => AuthUnknownException(
      code: 'verify-phone-failed',
      message: error.toString(),
    ),
  };

  /// Send-step mapping: only clearly transient codes count as network; the raw
  /// code is preserved for UX switching (invalid-phone-number,
  /// too-many-requests …), consistent with the diagnostics-only philosophy.
  /// The confirm-step codes (invalid-verification-code / -id) never arrive
  /// here — they belong to `signInWithCredential` in the repository.
  AuthException _mapFirebase(FirebaseAuthException failure) =>
      switch (failure.code) {
        'network-request-failed' => AuthNetworkException(
          message: failure.message,
        ),
        _ => AuthUnknownException(code: failure.code, message: failure.message),
      };
}
