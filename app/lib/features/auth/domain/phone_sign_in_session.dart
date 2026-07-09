/// Opaque handle to an in-progress phone sign-in, threaded from the send step
/// into the confirm step. Pure Dart — the Firebase verification id and resend
/// token never surface as Firebase types (docs/architecture.md §2;
/// brief-3.md fileEdits).
///
/// [verificationId] is the exact Firebase verification id returned by the
/// `codeSent` callback; [resendToken] is the platform `forceResendingToken`
/// fed back into a resend (null on iOS / the first send). Value equality is
/// load-bearing: the session is compared inside [PhoneSignInState], which
/// Riverpod's `updateShouldNotify` diffs with `==`.
final class PhoneSignInSession {
  const PhoneSignInSession(this.verificationId, {this.resendToken});

  final String verificationId;
  final int? resendToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneSignInSession &&
          other.verificationId == verificationId &&
          other.resendToken == resendToken;

  @override
  int get hashCode => Object.hash(verificationId, resendToken);

  @override
  String toString() =>
      'PhoneSignInSession(verificationId: $verificationId, '
      'resendToken: $resendToken)';
}
