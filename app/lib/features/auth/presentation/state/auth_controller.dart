import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data_rights/domain/data_rights_repository_provider.dart';
import '../../domain/auth_exception.dart';
import '../../domain/auth_repository_provider.dart';
import '../../domain/auth_state.dart';
import '../../domain/auth_user.dart';

part 'auth_controller.g.dart';

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
      final user = await repo.signInWithGoogle();
      if (!ref.mounted) return;
      state = AuthSignedIn(user);
    } on AuthCancelledException {
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

  /// Runs the native Sign in with Apple flow. Re-entrant calls are dropped
  /// while one is in flight (double-tap debounce).
  Future<void> signInWithApple() async {
    if (_manualInProgress) return;
    _manualInProgress = true;
    final repo = ref.read(authRepositoryProvider);
    state = const AuthSigningIn();
    try {
      final user = await repo.signInWithApple();
      if (!ref.mounted) return;
      state = AuthSignedIn(user);
    } on AuthCancelledException {
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
  Future<void> deleteAccount() async {
    if (_manualInProgress) return;
    _manualInProgress = true;
    final authRepo = ref.read(authRepositoryProvider);
    final dataRights = ref.read(dataRightsRepositoryProvider);
    try {
      // Phase 1: on any DataRightsException the state is left untouched and the
      // exception propagates past the `on AuthException` catch to the screen.
      await dataRights.deleteAccount();
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
}
