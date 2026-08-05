import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../domain/push_token_repository_provider.dart';
import '../../domain/push_token_source_provider.dart';

part 'push_token_sync.g.dart';

/// Keeps the device's FCM registration token in lockstep with the auth state
/// (ADR-042 Decision 1/D6), on the `PurchasesIdentitySync` mold.
///
/// [build] reads the CURRENT auth state and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session. A listen-only design would skip registration on every warm start,
/// which is the shape of the bug `PurchasesIdentitySync` was written to avoid.
///
/// **The sign-out removal is a privacy control, not a cleanup task.** A token
/// that outlives a sign-out delivers the NEXT user's pushes to the PREVIOUS
/// user's phone. It is best-effort all the same: `registerPushToken` evicts the
/// token from every other user document server-side (ADR-042 D1), so the property
/// survives a sign-out whose cleanup never ran — a killed app, a revoked session,
/// a phone in a drawer. Registration is authoritative; this is the prompt path,
/// not the load-bearing one.
///
/// **It removes the token it registered, not one re-read at sign-out.** FCM can
/// rotate a token between sign-in and sign-out, and removing the new one would
/// leave the old one on the departing user's document — the exact leak the call
/// exists to prevent.
///
/// Nothing here can take down the tree or block a frame: ADR-039 D1 makes the
/// boot fail-open and D2 bounds every wait on the launch→paired path. A device
/// with no token yet is the normal pre-permission state, not an error, and a
/// failure to obtain or register one is a logged no-op exactly as App Check and
/// Crashlytics fail open where they stand.
///
/// This provider is wired and **inert until `pushTokenSourceProvider` is
/// overridden** (ADR-042 D2 step 4, blocked on the App ID capability measured
/// absent on 2026-08-06). Resolving the source is deferred to the moment a sync
/// actually fires, so a signed-out lifecycle never touches it at all.
@Riverpod(keepAlive: true)
class PushTokenSync extends _$PushTokenSync {
  String? _syncedUid;

  /// The token this provider last registered — the one sign-out must remove.
  String? _registeredToken;

  StreamSubscription<String>? _refreshes;

  @override
  String? build() {
    _syncFrom(ref.read(authControllerProvider), initial: true);
    ref.listen(
      authControllerProvider,
      (_, next) => _syncFrom(next, initial: false),
    );
    ref.onDispose(() {
      unawaited(_refreshes?.cancel());
      _refreshes = null;
    });
    return _registeredToken;
  }

  void _syncFrom(AuthState authState, {required bool initial}) {
    if (authState is AuthSignedIn) {
      final uid = authState.user.uid;
      if (_syncedUid == uid) return;
      _syncedUid = uid;
      _listenForRefreshes();
      unawaited(_captureAndRegister(initial: initial));
    } else if (authState is AuthSignedOut) {
      if (_syncedUid == null) return;
      _syncedUid = null;
      unawaited(_removeRegistered(initial: initial));
    }
    // AuthSigningIn / AuthError are transient and drive no action — the same
    // rule PurchasesIdentitySync applies, and here it also keeps a token read
    // off the sign-in critical path.
  }

  /// Subscribes once. A rotation invalidates the previous token, so each event is
  /// a full re-registration rather than an addition — the server de-duplicates
  /// and caps regardless (ADR-042 D1), so a redundant register is cheap and a
  /// missed one is not.
  void _listenForRefreshes() {
    if (_refreshes != null) return;
    try {
      _refreshes = ref
          .read(pushTokenSourceProvider)
          .tokenRefreshes()
          .listen(
            (token) => unawaited(_register(token, initial: false)),
            onError: (Object failure) {
              debugPrint('PushTokenSync.tokenRefreshes failed: $failure');
            },
          );
    } catch (failure) {
      // No source overridden yet (the expected state until D2 step 4), or the
      // plugin failed to initialize. Either way: no pushes, no crash.
      debugPrint('PushTokenSync.tokenRefreshes unavailable: $failure');
    }
  }

  Future<void> _captureAndRegister({required bool initial}) async {
    try {
      final token = await ref.read(pushTokenSourceProvider).currentToken();
      if (token == null || token.isEmpty) return;
      await _register(token, initial: initial);
    } catch (failure) {
      debugPrint('PushTokenSync.currentToken failed: $failure');
    }
  }

  Future<void> _register(String token, {required bool initial}) async {
    // A refresh that arrives while signed out must register nothing: the
    // callable would attach the token to whoever happens to be signed in next.
    if (_syncedUid == null) return;
    try {
      await ref.read(pushTokenRepositoryProvider).register(token);
      _registeredToken = token;
      if (!initial) state = token;
    } catch (failure) {
      debugPrint('PushTokenSync.register failed: ${failure.runtimeType}');
    }
  }

  Future<void> _removeRegistered({required bool initial}) async {
    final token = _registeredToken;
    if (token == null) return;
    _registeredToken = null;
    if (!initial) state = null;
    try {
      await ref.read(pushTokenRepositoryProvider).unregister(token);
    } catch (failure) {
      debugPrint('PushTokenSync.unregister failed: ${failure.runtimeType}');
    }
  }
}
