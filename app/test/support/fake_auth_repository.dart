import 'dart:async';

import 'package:hayati_app/features/auth/domain/auth_repository.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';

/// Hand-written fake backing the domain/presentation tests. Behaviour knobs
/// beat mock stubbing here: the auth state machine is driven by a live stream
/// plus async sign-in outcomes, which the knobs below make explicit per test.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _currentUser = initialUser;

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;

  /// Behaviour of the next [signInWithGoogle] call. Tests must set this
  /// before triggering a sign-in; the fake throws otherwise so a missing
  /// arrangement fails loudly instead of hanging.
  Future<AuthUser> Function()? onSignInWithGoogle;

  /// Optional override for [signOut]; default clears [currentUser] silently
  /// (the real repository does not emit synchronously either — emissions are
  /// always explicit via [emit]).
  Future<void> Function()? onSignOut;

  int signInCalls = 0;
  int signOutCalls = 0;

  /// Pushes an external auth-state event (session restore, remote sign-out).
  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signInWithGoogle() {
    signInCalls++;
    final handler = onSignInWithGoogle;
    if (handler == null) {
      throw StateError(
        'FakeAuthRepository.onSignInWithGoogle was not configured.',
      );
    }
    return handler();
  }

  @override
  Future<void> signOut() {
    signOutCalls++;
    final handler = onSignOut;
    if (handler != null) {
      return handler();
    }
    _currentUser = null;
    return Future<void>.value();
  }

  Future<void> dispose() => _controller.close();
}
