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
  /// Ask the OS for notification permission, and report whether we now have it.
  ///
  /// **This is not optional plumbing — it is the gate everything else is behind.**
  /// On iOS `getToken()` cannot return a token until the user has authorised
  /// notifications, so without this call the entire feature is silent: the
  /// entitlement signs, the plugin initialises, the server composes and routes,
  /// and no device ever registers. That failure mode has no error surface, which
  /// is precisely why it is worth a sentence here.
  ///
  /// iOS shows its dialog **once per install** and never again, so WHEN this is
  /// called is a product decision, not a technical one — ADR-042 D6 puts it after
  /// pairing, on a screen that has already shown the user what the app is for,
  /// and never during boot (ADR-039 D1/D2: the boot is fail-open and every wait
  /// on the launch->paired path is bounded; a permission prompt is an indefinite
  /// wait on a human).
  ///
  /// Returns false rather than throwing when permission is denied or
  /// unavailable — a user who says no is an ordinary state, not an error.
  Future<bool> ensurePermission();

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
