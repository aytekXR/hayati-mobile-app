import 'auth_exception.dart';
import 'phone_sign_in_session.dart';

/// Screen-scoped state machine for the phone sign-in flow, driven by
/// `PhoneSignInController` (docs/resume-prompt.md M1.3).
///
/// Deliberately separate from `AuthState`: the phone flow has a user-input gap
/// between sending and confirming the SMS code, so it cannot be one atomic
/// operation and its intermediate states must never touch the global auth
/// precedence machine. The terminal signed-in transition is not modelled here —
/// it arrives on the `authStateChanges` stream once `signInWithCredential`
/// lands (brief-3.md DESIGN).
///
/// Value equality is load-bearing: Riverpod's `updateShouldNotify` uses `==`,
/// so re-emitting an equal state must not re-notify listeners.
sealed class PhoneSignInState {
  const PhoneSignInState();
}

/// Initial state: the user is entering their phone number.
final class PhoneEntry extends PhoneSignInState {
  const PhoneEntry();

  @override
  bool operator ==(Object other) => other is PhoneEntry;

  @override
  int get hashCode => (PhoneEntry).hashCode;

  @override
  String toString() => 'PhoneEntry()';
}

/// A first-time SMS code request is in flight.
final class PhoneSending extends PhoneSignInState {
  const PhoneSending();

  @override
  bool operator ==(Object other) => other is PhoneSending;

  @override
  int get hashCode => (PhoneSending).hashCode;

  @override
  String toString() => 'PhoneSending()';
}

/// A code was sent for [session] and the user is entering it. [resending] is
/// true while a resend request is in flight, so the code-entry UI stays
/// visible (there is no resend cooldown this session — brief-3.md).
final class PhoneCodeSent extends PhoneSignInState {
  const PhoneCodeSent(this.session, {this.resending = false});

  final PhoneSignInSession session;
  final bool resending;

  @override
  bool operator ==(Object other) =>
      other is PhoneCodeSent &&
      other.session == session &&
      other.resending == resending;

  @override
  int get hashCode => Object.hash(session, resending);

  @override
  String toString() =>
      'PhoneCodeSent(session: $session, resending: $resending)';
}

/// The entered code is being confirmed against [session].
final class PhoneConfirming extends PhoneSignInState {
  const PhoneConfirming(this.session);

  final PhoneSignInSession session;

  @override
  bool operator ==(Object other) =>
      other is PhoneConfirming && other.session == session;

  @override
  int get hashCode => session.hashCode;

  @override
  String toString() => 'PhoneConfirming(session: $session)';
}

/// A step failed with [failure]. [session] is retained when the failure is
/// recoverable on the code-entry screen (e.g. [AuthInvalidCodeException]) and
/// null when the flow must restart from phone entry (e.g. a send failure or
/// [AuthSessionExpiredException]).
final class PhoneSignInFailure extends PhoneSignInState {
  const PhoneSignInFailure(this.failure, {this.session});

  final AuthException failure;
  final PhoneSignInSession? session;

  @override
  bool operator ==(Object other) =>
      other is PhoneSignInFailure &&
      other.failure == failure &&
      other.session == session;

  @override
  int get hashCode => Object.hash(failure, session);

  @override
  String toString() =>
      'PhoneSignInFailure(failure: $failure, session: $session)';
}
