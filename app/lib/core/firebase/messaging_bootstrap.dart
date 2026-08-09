import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Tell iOS to DISPLAY a push that arrives while the app is in the FOREGROUND
/// (ADR-044 addendum, issue #188).
///
/// **Without this, a delivered notification shows nothing when the app is
/// open.** iOS's default foreground behaviour is to hand the payload to the app
/// and present no banner, no sound and no badge; `firebase_messaging` only
/// overrides that when this option is set. The message is not lost — it is
/// simply invisible, which is indistinguishable from "notifications are still
/// broken" to the person testing them.
///
/// That matters unevenly across the three pushes, which is why it is worth
/// fixing rather than filing:
///
/// * the **08:00 daily question** lands when the app is almost certainly
///   backgrounded, so it was never affected;
/// * **"your partner answered"** fires the instant the other member submits —
///   precisely when the recipient is most likely to have the app open. The
///   founder's own words for this feature were *"or your partner is answered"*,
///   and it is the one most likely to be tested by two people using the app at
///   the same time.
///
/// **Called ONLY by the flavor entrypoints**, never from `initializeFirebase` —
/// the same rule `activateAppCheck` and `initializeCrashlytics` follow, and for
/// the same reason: this drives a platform channel and throws in the plain test
/// VM, while `initializeFirebase` is unit-tested there (`architecture.md` §2).
///
/// **Fail-open and never awaited (ADR-039 D1/D2, ADR-022).** A foreground
/// presentation preference is a display nicety; blocking the first frame on a
/// channel round-trip to set it would trade a real cost (launch latency) for a
/// cosmetic one. A throw is a logged no-op, exactly as App Check and Crashlytics
/// fail open where they stand.
///
/// **Deliberately thin and deliberately untested**, on the same trade as
/// `FcmPushTokenSource` (ADR-042 D2): one plugin call with no branches of its
/// own, where a fake would satisfy any assertion the real thing would.
///
/// Harmless on Android, where the OS decides foreground presentation itself.
Future<void> configureForegroundNotifications() async {
  try {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  } catch (failure) {
    // A device or a test VM without the plugin channel is not an error worth
    // surfacing: every push still arrives, and still displays whenever the app
    // is backgrounded, which is the common case.
    debugPrint('configureForegroundNotifications failed: $failure');
  }
}
