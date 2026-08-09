import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_token_source.dart';

/// The FCM implementation of [PushTokenSource] (ADR-042 D2 step 4).
///
/// This is the whole device half of the token lifecycle: one class, because
/// everything that DECIDES anything — when to register, what to remove at
/// sign-out, how to survive a rotation — lives above the port in `PushTokenSync`
/// and is proven on Linux with a fake. That was the point of the seam.
///
/// **It is deliberately thin and deliberately untested**, the same trade
/// `FunctionsDataRightsRepository` documents: an adapter with no branches of its
/// own has nothing to assert about that a fake would not also satisfy. The one
/// thing it does carry is the fail-open posture, and that IS tested — through
/// `PushTokenSync`, which treats a throw or a null from here as a logged no-op.
///
/// ## What it is not doing, and why
///
/// **It does not request notification permission.** ADR-039 D1 makes the boot
/// fail-open and D2 bounds every wait on the launch→paired path; a permission
/// prompt is an indefinite wait on a human and iOS gives one shot per install.
/// ADR-042 D6 puts the ask after pairing, on a screen that can explain itself —
/// so it belongs to a UI surface, not to this adapter. Until that ships,
/// [currentToken] simply returns null on iOS, which is the normal pre-permission
/// state and exactly what the fail-open path is for.
///
/// **It does not assume APNs works.** Without `aps-environment` in the
/// entitlements — absent by design until the App ID capability is ticked
/// (measured absent 2026-08-06) — iOS never hands Firebase an APNs token, so
/// `getToken()` returns null or throws. Both collapse to "no token yet", the
/// same state as a user who has not granted permission. **This class is
/// therefore correct and inert today, and becomes live the moment the
/// entitlement lands, with no code change.**
class FcmPushTokenSource implements PushTokenSource {
  FcmPushTokenSource({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<bool> ensurePermission() async {
    // requestPermission() is idempotent from the caller's side: iOS shows its
    // dialog only on the first call per install and thereafter returns the
    // standing answer, so a repeated call is a cheap read rather than a repeated
    // interruption. `provisional: false` deliberately — a provisional grant
    // delivers quietly to the notification centre with no alert, which for a
    // couples app whose whole point is "your partner answered" would look
    // exactly like the feature not working.
    final settings = await _messaging.requestPermission();
    final status = settings.authorizationStatus;
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  @override
  Future<bool> isReadyForToken() async {
    // ADR-044 D1. iOS mints an FCM token only once APNs has handed the app a
    // device token, and that arrives asynchronously AFTER the permission grant.
    // Asking `getToken()` before then throws `apns-token-not-set` — so this is
    // the question that has to be answered first, and `PushTokenSync` owns the
    // waiting.
    //
    // Thin by contract (ADR-042 D2): one call, no branches of its own beyond the
    // platform test, nothing to assert about that a fake would not also satisfy.
    if (!Platform.isIOS) return true;
    try {
      return await _messaging.getAPNSToken() != null;
    } catch (_) {
      // Not "no" — "cannot tell". The caller retries either way, and a throw
      // here must never be louder than a null.
      return false;
    }
  }

  @override
  Future<String?> currentToken() async {
    // On iOS, getToken() throws rather than returning null when APNs has not
    // registered. `isReadyForToken` above is what keeps this call out of that
    // window; the caller still treats a throw as "not yet" and retries, because
    // an adapter that can throw for an ordinary absence must not be able to
    // convert one unlucky moment into permanent silence (ADR-044 D2).
    return _messaging.getToken();
  }

  @override
  Stream<String> tokenRefreshes() => _messaging.onTokenRefresh;
}
