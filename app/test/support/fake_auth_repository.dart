import 'dart:async';

import 'package:hayati_app/features/auth/domain/auth_repository.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/domain/phone_sign_in_session.dart';

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

  /// Behaviour of the next [signInWithApple] call; same loud-default contract
  /// as [onSignInWithGoogle].
  Future<AuthUser> Function()? onSignInWithApple;

  /// Optional override for [signOut]; default clears [currentUser] silently
  /// (the real repository does not emit synchronously either — emissions are
  /// always explicit via [emit]).
  Future<void> Function()? onSignOut;

  /// Optional override for [signOutAfterAccountDeletion] (ADR-019 D7 phase 2);
  /// default clears [currentUser] silently. Set it to throw an [AuthException] to
  /// drive the phase-2 self-heal path (AuthError + lock intact).
  Future<void> Function()? onSignOutAfterAccountDeletion;

  /// Behaviour of the next [sendPhoneCode] call. Tests must set this before
  /// triggering the phone flow; the fake throws otherwise so a missing
  /// arrangement fails loudly instead of hanging.
  Future<PhoneSignInSession> Function(
    String phoneNumber, {
    PhoneSignInSession? resendFrom,
  })?
  onSendPhoneCode;

  /// Behaviour of the next [confirmPhoneCode] call; same loud-default contract.
  Future<AuthUser> Function(PhoneSignInSession session, String smsCode)?
  onConfirmPhoneCode;

  int signInCalls = 0;
  int signInWithAppleCalls = 0;
  int signOutCalls = 0;
  int signOutAfterAccountDeletionCalls = 0;
  int sendPhoneCodeCalls = 0;
  int confirmPhoneCodeCalls = 0;

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
  Future<AuthUser> signInWithApple() {
    signInWithAppleCalls++;
    final handler = onSignInWithApple;
    if (handler == null) {
      throw StateError(
        'FakeAuthRepository.onSignInWithApple was not configured.',
      );
    }
    return handler();
  }

  @override
  Future<PhoneSignInSession> sendPhoneCode(
    String phoneNumber, {
    PhoneSignInSession? resendFrom,
  }) {
    sendPhoneCodeCalls++;
    final handler = onSendPhoneCode;
    if (handler == null) {
      throw StateError(
        'FakeAuthRepository.onSendPhoneCode was not configured.',
      );
    }
    return handler(phoneNumber, resendFrom: resendFrom);
  }

  @override
  Future<AuthUser> confirmPhoneCode(
    PhoneSignInSession session,
    String smsCode,
  ) {
    confirmPhoneCodeCalls++;
    final handler = onConfirmPhoneCode;
    if (handler == null) {
      throw StateError(
        'FakeAuthRepository.onConfirmPhoneCode was not configured.',
      );
    }
    return handler(session, smsCode);
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

  @override
  Future<void> signOutAfterAccountDeletion() {
    signOutAfterAccountDeletionCalls++;
    final handler = onSignOutAfterAccountDeletion;
    if (handler != null) {
      return handler();
    }
    _currentUser = null;
    return Future<void>.value();
  }

  Future<void> dispose() => _controller.close();
}
