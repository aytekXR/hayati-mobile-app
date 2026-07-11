import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../domain/purchases_repository_provider.dart';

part 'purchases_identity_sync.g.dart';

/// Keeps the RevenueCat identity in lockstep with the auth state (M4.2, ADR-014
/// Decision 2). keepAlive + activated from the app root (app.dart) via
/// `ref.listen(..., (_, _) {})` — the always-mounted seam.
///
/// [build] reads the CURRENT auth state first and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session; a listen-only design would skip `logIn` on every warm start and the
/// purchase guard would then block every legitimate warm-start purchase.
///
/// The state value is the last-synced identity (uid, or null when signed out) —
/// incidental; the sync is the side effect. Dedupe tracks that identity
/// including signed-out: `uid → same uid` and `null → null` are no-ops, and
/// `logOut()` fires only on a real signed-in → signed-out transition (never as
/// an initial action — `Purchases.logOut()` throws when the RC user is already
/// anonymous). `AuthSigningIn`/`AuthError` are transient and drive no action.
/// The purchases repository is resolved lazily, only when a sync action fires,
/// so a signed-out lifecycle never touches `purchasesRepositoryProvider`.
@Riverpod(keepAlive: true)
class PurchasesIdentitySync extends _$PurchasesIdentitySync {
  String? _lastSyncedUid;

  @override
  String? build() {
    _syncFrom(ref.read(authControllerProvider), initial: true);
    ref.listen(
      authControllerProvider,
      (_, next) => _syncFrom(next, initial: false),
    );
    return _lastSyncedUid;
  }

  void _syncFrom(AuthState authState, {required bool initial}) {
    if (authState is AuthSignedIn) {
      final uid = authState.user.uid;
      if (_lastSyncedUid == uid) return;
      _lastSyncedUid = uid;
      if (!initial) state = uid;
      unawaited(_logIn(uid));
    } else if (authState is AuthSignedOut) {
      if (_lastSyncedUid == null) return;
      _lastSyncedUid = null;
      if (!initial) state = null;
      unawaited(_logOut());
    }
    // AuthSigningIn / AuthError: transient — the tracker is left untouched.
  }

  Future<void> _logIn(String uid) async {
    try {
      await ref.read(purchasesRepositoryProvider).logIn(uid);
    } catch (failure) {
      // A background sync must never take down the tree; the purchase guard is
      // the enforcement backstop.
      debugPrint('PurchasesIdentitySync.logIn failed: $failure');
    }
  }

  Future<void> _logOut() async {
    try {
      await ref.read(purchasesRepositoryProvider).logOut();
    } catch (failure) {
      debugPrint('PurchasesIdentitySync.logOut failed: $failure');
    }
  }
}
