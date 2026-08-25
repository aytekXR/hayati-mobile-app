import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/local_flag_store.dart';
import '../../../data_rights/domain/data_rights_repository_provider.dart';
import '../../domain/auth_exception.dart';
import '../../domain/auth_repository_provider.dart';
import '../../domain/auth_state.dart';
import '../../domain/auth_user.dart';

part 'auth_controller.g.dart';

/// Ceiling on an INTERACTIVE provider sign-in (ADR-039).
///
/// [AuthSigningIn] renders a bare spinner on the auth shell — correctly, because
/// a system sheet is up and there is nothing else to offer. But the state is only
/// ever left by the sign-in future completing, and that future crosses two things
/// this app does not control: a native authorization sheet, and a Firebase
/// credential exchange that waits on an App Check token before it will issue its
/// request. Neither is guaranteed to call back. When one did not, the app sat on
/// that spinner permanently — with the provider buttons gone, because the shell
/// had already swapped them out.
///
/// Two minutes, because the clock covers a HUMAN: reading the sheet, typing an
/// Apple ID password, waiting for a 2FA code to arrive on another device. Any
/// bound short enough to feel responsive would cancel real sign-ins, so the bound
/// exists to end an infinity, not to be prompt.
///
/// A late success is NOT lost. The timeout releases the manual-op gate, so the
/// repository stream — which the gate was suppressing — becomes the source of
/// truth again: if the sign-in lands after the deadline, `_onAuthUser` puts the
/// user straight into [AuthSignedIn] from under the error view.
const Duration kInteractiveSignInTimeout = Duration(minutes: 2);

/// The failure [kInteractiveSignInTimeout] lands on.
///
/// Typed as NETWORK, not unknown, and that is the whole point of the choice: the
/// error view renders "Check your connection and try again" instead of the
/// generic "Something went wrong". A sign-in that ran two minutes without a
/// verdict is overwhelmingly a connectivity problem, and network copy is the one
/// piece of advice that is both honest and actionable. The message field keeps
/// the distinguishing detail for a log without putting it in front of the user.
const AuthException _signInTimedOut = AuthNetworkException(
  message: 'interactive sign-in timed out',
);

/// Drives the auth state machine (docs/resume-prompt.md M1.1).
///
/// Precedence contract: while a manual operation (sign-in/sign-out) is in
/// flight it owns the state — repository stream emissions are ignored until
/// it settles, so Firebase's mid-flight emissions can't clobber
/// [AuthSigningIn] or race the operation's terminal state. When idle, the
/// stream is the single source of truth (session restore, remote sign-out).
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  bool _manualInProgress = false;

  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    final subscription = repo.authStateChanges().listen(_onAuthUser);
    ref.onDispose(subscription.cancel);
    final user = repo.currentUser;
    return user == null ? const AuthSignedOut() : AuthSignedIn(user);
  }

  void _onAuthUser(AuthUser? user) {
    if (_manualInProgress) return;
    state = user == null ? const AuthSignedOut() : AuthSignedIn(user);
  }

  /// Runs the interactive Google flow. Re-entrant calls are dropped while
  /// one is in flight (double-tap debounce).
  Future<void> signInWithGoogle() async {
    if (_manualInProgress) return;
    _manualInProgress = true;
    final repo = ref.read(authRepositoryProvider);
    state = const AuthSigningIn();
    try {
      final user = await repo.signInWithGoogle().timeout(
        kInteractiveSignInTimeout,
      );
      if (!ref.mounted) return;
      state = AuthSignedIn(user);
    } on AuthCancelledException {
      if (!ref.mounted) return;
      state = const AuthSignedOut();
    } on TimeoutException {
      // Not an AuthException — it never crossed the repository boundary — so it
      // needs its own arm or it would escape `unawaited` into the zone handler
      // and leave the spinner up, which is the failure this bound exists for.
      if (!ref.mounted) return;
      state = const AuthError(_signInTimedOut);
    } on AuthException catch (failure) {
      if (!ref.mounted) return;
      state = AuthError(failure);
    } finally {
      if (ref.mounted) {
        _manualInProgress = false;
      }
    }
  }

  /// Runs the native Sign in with Apple flow. Re-entrant calls are dropped
  /// while one is in flight (double-tap debounce). Bounded by
  /// [kInteractiveSignInTimeout].
  Future<void> signInWithApple() async {
    if (_manualInProgress) return;
    _manualInProgress = true;
    final repo = ref.read(authRepositoryProvider);
    state = const AuthSigningIn();
    try {
      final user = await repo.signInWithApple().timeout(
        kInteractiveSignInTimeout,
      );
      if (!ref.mounted) return;
      state = AuthSignedIn(user);
    } on AuthCancelledException {
      if (!ref.mounted) return;
      state = const AuthSignedOut();
    } on TimeoutException {
      // See the Google arm: TimeoutException is not an AuthException.
      if (!ref.mounted) return;
      state = const AuthError(_signInTimedOut);
    } on AuthException catch (failure) {
      if (!ref.mounted) return;
      state = AuthError(failure);
    } finally {
      if (ref.mounted) {
        _manualInProgress = false;
      }
    }
  }

  Future<void> signOut() async {
    if (_manualInProgress) return;
    _manualInProgress = true;
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signOut();
      if (!ref.mounted) return;
      state = const AuthSignedOut();
    } on AuthException catch (failure) {
      if (!ref.mounted) return;
      state = AuthError(failure);
    } finally {
      if (ref.mounted) {
        _manualInProgress = false;
      }
    }
  }

  /// Runs the KVKK/PDPL account deletion (ADR-019 Decision 7). The manual-op gate
  /// spans the WHOLE operation (so a stream `null` mid-teardown can never race the
  /// terminal state), but the two phases have deliberately different state owners:
  ///
  /// **Phase 1 — the server cascade — is a LOCAL operation.** A callable failure
  /// leaves [state] EXACTLY as it was ([AuthSignedIn] — nothing transitions,
  /// nothing pops, so the host settings screen's auth-loss self-pop never fires
  /// and the delete screen survives to render its retry copy) and the typed
  /// [DataRightsException] propagates to the screen. It is NOT an [AuthException],
  /// so the `on AuthException` catch below deliberately does NOT swallow it; the
  /// finally still releases the gate. Re-driving is safe (Decision 2 idempotency).
  ///
  /// **Phase 2 — session teardown — only after server success.** The Google half
  /// is attempted and swallowed inside the repository (meaningless residue);
  /// `signOutAfterAccountDeletion` runs the Firebase sign-out; on success the
  /// controller sets [AuthSignedOut] EXPLICITLY. The pre-state is [AuthSignedIn],
  /// so that value-inequal transition fires the root listener's lock `wipe()`.
  ///
  /// **If phase 2 throws:** [AuthError]. Protection stays; the host self-pop dumps
  /// to the root shell; the dead session self-heals to [AuthSignedOut] on its next
  /// token-refresh failure (≤~1h) — the D8 row-7 correction (a completed deletion
  /// masquerading as an error must not be stranded in "retry forever").
  ///
  /// **Between the two phases, the device's own account data goes** (ADR-061 D1).
  /// This is the only place in the app that knows a DELETION happened rather than
  /// a sign-out — both end in [AuthSignedOut], so the app-root listener cannot
  /// tell them apart and must not carry this.
  Future<void> deleteAccount() async {
    if (_manualInProgress) return;
    _manualInProgress = true;
    final authRepo = ref.read(authRepositoryProvider);
    final dataRights = ref.read(dataRightsRepositoryProvider);
    // Read BEFORE phase 1: the cascade destroys the account, and phase 2 signs
    // the session out. Afterwards there is nobody left to name.
    final uid = authRepo.currentUser?.uid;
    try {
      // Phase 1: on any DataRightsException the state is left untouched and the
      // exception propagates past the `on AuthException` catch to the screen —
      // so the flag sweep below never runs for a deletion that did not happen.
      await dataRights.deleteAccount();
      if (!ref.mounted) return;
      await _clearAccountScopedFlags(uid);
      if (!ref.mounted) return;
      // Phase 2: teardown only after server success.
      await authRepo.signOutAfterAccountDeletion();
      if (!ref.mounted) return;
      state = const AuthSignedOut();
    } on AuthException catch (failure) {
      if (!ref.mounted) return;
      state = AuthError(failure);
    } finally {
      if (ref.mounted) {
        _manualInProgress = false;
      }
    }
  }

  /// Removes every flag this device holds for [uid] (ADR-061 D1), after the
  /// server cascade has succeeded and before the session is torn down.
  ///
  /// **Nothing here can fail the deletion** (ADR-061 D3). `localFlagStoreProvider`
  /// throws when unoverridden and a platform write can fail on a real phone;
  /// either way the account is already gone on the server, and telling the user
  /// their completed deletion failed would be the worse error. It degrades to
  /// flags left behind — visible only to the person whose phone it is, and never
  /// to a second account.
  Future<void> _clearAccountScopedFlags(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      await ref.read(localFlagStoreProvider).removeAccountScoped(uid);
    } on Object {
      // Deliberately silent, and deliberately not a crash-reporter hop: this
      // runs inside a deletion, and a telemetry call on that path is exactly
      // what ADR-019's no-push posture keeps off it.
    }
  }
}
