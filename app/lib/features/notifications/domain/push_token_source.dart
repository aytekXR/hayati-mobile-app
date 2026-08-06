/// The device-side twin of the server's `MessagingPort` (ADR-042 Decision 2).
///
/// The whole point is that nothing above this line knows FCM exists. The token
/// lifecycle — capture, refresh, registration, eviction, sign-out removal — is
/// therefore provable on Linux with no `firebase_messaging`, no Mac and no APNs
/// key, which is the same trade ADR-012 D3 made for the send side and the reason
/// its Functions half was provable at all.
///
/// **There is deliberately no implementation of this yet.** ADR-042 D2 orders the
/// device work behind a measured fact: `PUSH_NOTIFICATIONS` is not ticked on the
/// App ID (measured 2026-08-06), `match` fetches provisioning profiles readonly
/// (ADR-032), and a build claiming `aps-environment` without the capability fails
/// at codesign — in the macOS release job, because `ios-build-smoke` runs
/// `--no-codesign` and cannot see it coming. So the FCM adapter is one class
/// written when the plugin lands, and everything that decides anything is here
/// and tested now.
abstract interface class PushTokenSource {
  /// The current registration token, or null when the device has none yet —
  /// permission not granted, APNs not reachable, or the plugin not installed.
  ///
  /// Never throws for an ordinary absence: a device without a token is the
  /// normal state before permission, not an error. ADR-039's fail-open posture
  /// applies — a failure here is a logged no-op, exactly as App Check and
  /// Crashlytics fail open where they stand.
  Future<String?> currentToken();

  /// Tokens as FCM rotates them. A refresh invalidates the previous token, so
  /// each event is a full re-registration rather than an addition.
  Stream<String> tokenRefreshes();
}
