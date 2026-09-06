import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/platform/device_privacy_channel.dart';
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
/// so it belongs to a UI surface, not to this adapter. **That surface shipped**:
/// `PairedHomeScreen.initState` calls `promptForPermissionAndRegister()` from a
/// post-frame callback. Before a grant, [currentToken] simply returns null on
/// iOS, which is the normal pre-permission state and what the fail-open path is
/// for.
///
/// **It does not assume APNs works.** iOS hands Firebase an APNs token
/// asynchronously and only after a permission grant; before that `getToken()`
/// returns null or throws. Both collapse to "no token yet", the same state as a
/// user who has not granted permission — which is why `isReadyForToken` exists
/// and why `PushTokenSync` owns the bounded retry (ADR-044).
///
/// ⚠️ This paragraph used to end *"This class is therefore correct and inert
/// today, and becomes live the moment the entitlement lands"*. **The entitlement
/// landed 2026-08-07** and the sentence stayed for twenty days (ADR-063). It is
/// not inert. What a phone actually reports is measured, never assumed:
/// `python3 tool/ci/push_delivery_probe.py --from-firebase-cli`.
class FcmPushTokenSource implements PushTokenSource {
  FcmPushTokenSource({
    FirebaseMessaging? messaging,
    DevicePrivacyChannel? channel,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _channel = channel ?? const DevicePrivacyChannel();

  final FirebaseMessaging _messaging;

  /// The app's ONE platform channel (ADR-018 D6), for the one push fact the
  /// `firebase_messaging` plugin has but does not expose: the APNs refusal.
  final DevicePrivacyChannel _channel;

  @override
  Future<PushPermission> permissionStatus() async {
    // ADR-046 D1. `getNotificationSettings()` READS the standing answer and
    // shows nothing — unlike `requestPermission()`, which consumes iOS's
    // one-per-install dialog. That difference is why these are two methods and
    // not a flag, and why this one is safe to call on every mount and resume.
    //
    // Thin by contract (ADR-042 D2): one call and a mapping, nothing a fake
    // would not also satisfy.
    try {
      final settings = await _messaging.getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied => PushPermission.denied,
        // `notDetermined` and anything a future plugin version adds. Fail-open
        // to the state that costs the user nothing: it offers the prompt, and
        // the prompt is a no-op when the answer already exists.
        _ => PushPermission.notDetermined,
      };
    } catch (_) {
      return PushPermission.notDetermined;
    }
  }

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
      if (await _messaging.getAPNSToken() != null) return true;
    } catch (_) {
      // Not "no" — "cannot tell". The caller retries either way, and a throw
      // here must never be louder than a null.
      return false;
    }
    // NO ADDRESS YET — so make sure somebody actually ASKED for one (S101).
    //
    // ⚠️ This is not a retry of the read; it is a retry of the REQUEST, and
    // until now nothing in this project made that request itself.
    // `firebase_messaging` issues `registerForRemoteNotifications` from its
    // launch/scene setup and only when `[FIRMessaging messaging]
    // .isAutoInitEnabled` — a check whose ordering against Dart's
    // `Firebase.initializeApp` this app does not control, because it configures
    // Firebase from pure-Dart options with no `GoogleService-Info.plist`. If
    // that check lands before there is a `FirebaseApp`, nothing ever asks APNs
    // and `getAPNSToken()` is nil forever: permission granted, no address, no
    // error — the state measured in production on 2026-09-06, twice, 78 minutes
    // apart.
    //
    // Apple documents the call as idempotent, so this is free when the plugin
    // already succeeded. Fire-and-forget: it must not make the readiness answer
    // depend on a channel round-trip, and the bounded loop above will ask again
    // in half a second either way (ADR-044 D1).
    unawaited(_askApnsToRegister());
    return false;
  }

  /// Request APNs registration, swallowing everything.
  ///
  /// A missing native half (an older binary, a platform with no such concept)
  /// must not turn the readiness probe into a throw — the caller reads a throw
  /// as "not yet" and would keep its meaning, but the log line would blame the
  /// wrong link, which is the confusion ADR-049 exists to end.
  Future<void> _askApnsToRegister() async {
    try {
      await _channel.ensureRemoteNotificationRegistration();
    } catch (_) {
      // Nothing to say that the diagnostic does not already say better.
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

  @override
  Future<String?> apnsRegistrationFailure() async {
    // Only iOS has the callback this reads; asking anywhere else would cross the
    // channel for an answer the native side does not model.
    if (!Platform.isIOS) return null;
    try {
      return await _channel.apnsRegistrationFailure();
    } catch (_) {
      // A missing channel handler (an older native half, a test harness with no
      // platform) is "cannot tell", not "refused". Claiming a refusal we did not
      // observe would be worse than the silence this method exists to break.
      return null;
    }
  }
}
