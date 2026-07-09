import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/auth_exception.dart';
import '../../domain/auth_repository_provider.dart';
import '../../domain/phone_sign_in_session.dart';
import '../../domain/phone_sign_in_state.dart';

part 'phone_sign_in_controller.g.dart';

/// Screen-scoped driver for the phone sign-in flow (docs/resume-prompt.md
/// M1.3). autoDispose: it is bound to the phone screen's lifetime and reset
/// on every fresh entry.
///
/// Precedence contract: this controller NEVER writes the global `AuthState`.
/// The phone flow has a user-input gap between sending and confirming the code
/// so it cannot be one atomic operation, and injecting intermediate states
/// into the global machine would corrupt its stream-vs-manual precedence. On a
/// successful confirm the controller deliberately stays in [PhoneConfirming]:
/// the terminal `AuthSignedIn` arrives on the `authStateChanges` stream while
/// the global `AuthController` is idle, and the screen is torn down then
/// (brief-3.md DESIGN).
///
/// [confirm]'s two purposeful branches: [AuthInvalidCodeException] keeps the
/// session so the user can re-enter the code inline; [AuthSessionExpiredException]
/// discards it so the UI restarts from phone entry.
@riverpod
class PhoneSignInController extends _$PhoneSignInController {
  /// The number last sent to, so [resend] can re-request without re-collecting
  /// it. Set on every [sendCode].
  String? _phoneNumber;

  /// Single-flight guard: drops re-entrant taps while an operation is running.
  bool _busy = false;

  @override
  PhoneSignInState build() => const PhoneEntry();

  /// Requests a first SMS code for [phoneNumber]. No E.164 validation beyond
  /// what the backend enforces — malformed numbers surface as failures.
  Future<void> sendCode(String phoneNumber) async {
    if (_busy) return;
    _busy = true;
    _phoneNumber = phoneNumber;
    state = const PhoneSending();
    await _send(phoneNumber);
  }

  /// Re-requests the code for the current session (no cooldown this session).
  /// A no-op unless a code has already been sent.
  Future<void> resend() async {
    if (_busy) return;
    final current = state;
    if (current is! PhoneCodeSent) return;
    _busy = true;
    state = PhoneCodeSent(current.session, resending: true);
    await _send(_phoneNumber!, resendFrom: current.session);
  }

  Future<void> _send(
    String phoneNumber, {
    PhoneSignInSession? resendFrom,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final newSession = await repo.sendPhoneCode(
        phoneNumber,
        resendFrom: resendFrom,
      );
      if (!ref.mounted) return;
      state = PhoneCodeSent(newSession);
    } on AuthException catch (failure) {
      if (!ref.mounted) return;
      // A failed FIRST send has no session to retry against and restarts from
      // entry. A failed RESEND keeps [resendFrom]: the prior verificationId is
      // still valid (the resend never replaced it), so the user can enter the
      // code they already received instead of restarting — and re-sending is
      // exactly what just failed, typically on 'too-many-requests'.
      state = PhoneSignInFailure(failure, session: resendFrom);
    } finally {
      if (ref.mounted) _busy = false;
    }
  }

  /// Confirms [smsCode] against the current session. A no-op when there is no
  /// session in flight (still on phone entry / sending).
  Future<void> confirm(String smsCode) async {
    if (_busy) return;
    final session = _sessionInFlight;
    if (session == null) return;
    _busy = true;
    state = PhoneConfirming(session);
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.confirmPhoneCode(session, smsCode);
      // Deliberately no state write on success: AuthSignedIn arrives via
      // authStateChanges; the screen is disposed then (brief-3.md DESIGN).
    } on AuthSessionExpiredException catch (failure) {
      if (!ref.mounted) return;
      // Dead session: drop it so the UI returns to phone entry.
      state = PhoneSignInFailure(failure);
    } on AuthException catch (failure) {
      if (!ref.mounted) return;
      // Recoverable (wrong code, network …): keep the session for inline retry.
      state = PhoneSignInFailure(failure, session: session);
    } finally {
      if (ref.mounted) _busy = false;
    }
  }

  /// The session usable for a confirm, whether waiting for input, mid-confirm,
  /// or recovering from a retained-session failure.
  PhoneSignInSession? get _sessionInFlight => switch (state) {
    PhoneCodeSent(:final session) => session,
    PhoneConfirming(:final session) => session,
    PhoneSignInFailure(:final session) => session,
    _ => null,
  };
}
