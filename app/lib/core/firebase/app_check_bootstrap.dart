import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'firebase_bootstrap.dart' show kUseAuthEmulator;

/// App Check debug token for an automatable on-device dev leg, injected via
/// `--dart-define=APP_CHECK_DEBUG_TOKEN=...` (empty by default). Used only for
/// the dev Apple debug provider, and the token must be pre-registered in the
/// Firebase console (docs/resume-prompt.md M1.3).
const String kAppCheckDebugToken = String.fromEnvironment(
  'APP_CHECK_DEBUG_TOKEN',
);

/// Pure flavor→Apple provider selection, unit-tested without any channel: dev
/// uses the debug provider (token via logs or [kAppCheckDebugToken]), prod uses
/// App Attest — always available at the app's min iOS 15.0 (≥ the 14.0 floor).
AppleAppCheckProvider appCheckAppleProviderFor(AppFlavor flavor) =>
    switch (flavor) {
      AppFlavor.dev => const AppleDebugProvider(),
      AppFlavor.prod => const AppleAppAttestProvider(),
    };

/// Pure flavor→Android provider selection, future-proofing the Android slice
/// (ADR-006 / M6.5): dev uses the debug provider, prod uses Play Integrity.
AndroidAppCheckProvider appCheckAndroidProviderFor(AppFlavor flavor) =>
    switch (flavor) {
      AppFlavor.dev => const AndroidDebugProvider(),
      AppFlavor.prod => const AndroidPlayIntegrityProvider(),
    };

/// Activates App Check for [config]'s flavor. Called ONLY by the flavor
/// entrypoints after `initializeFirebase` — never from `initializeFirebase`
/// itself or any test-reachable path — because `activate()` drives a Pigeon
/// channel and throws `FirebaseException('channel-error')` in the plain test
/// VM (docs/resume-prompt.md M1.3). Skipped under the Auth emulator as
/// defense-in-depth so the integration leg stays hermetic. Uses the
/// `providerApple:`/`providerAndroid:` named params, not the deprecated enums.
///
/// FAIL-OPEN (ADR-039). This is the FIRST of the two futures in the
/// pre-first-frame `.wait`, and it crosses a Pigeon channel into native
/// Firebase — where provider registration can reject for reasons that are
/// properties of the DEVICE and the BUILD, not of this code (App Attest
/// unsupported or unavailable, a mis-provisioned binary, a channel that is not
/// up yet). A throw here propagated out of `main()` as a `ParallelWaitError`,
/// so `runApp` was never reached and the app sat on the launch image forever.
/// An attestation problem presented as a dead splash.
///
/// The right failure direction is not a judgement call: App Check is a
/// SERVER-SIDE enforcement signal. Requests carry a token or they do not, and
/// the backend decides — the client blocking its own boot protects nobody and
/// merely converts "some requests may be refused" into "the app never starts".
Future<void> activateAppCheck(AppConfig config) async {
  if (kUseAuthEmulator) return;
  final apple = config.flavor == AppFlavor.dev && kAppCheckDebugToken.isNotEmpty
      ? const AppleDebugProvider(debugToken: kAppCheckDebugToken)
      : appCheckAppleProviderFor(config.flavor);
  try {
    await FirebaseAppCheck.instance.activate(
      providerApple: apple,
      providerAndroid: appCheckAndroidProviderFor(config.flavor),
    );
  } catch (failure) {
    debugPrint('App Check activation failed, continuing without it: $failure');
  }
}
