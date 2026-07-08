import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

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
}
