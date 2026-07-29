import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'crash_reporter.dart';
import 'crashlytics_crash_reporter.dart';
import 'noop_crash_reporter.dart';

/// Constructs the Crashlytics-backed [CrashReporter] and applies the per-flavor
/// collection policy — dev OFF, prod ON — via the runtime API (which persists
/// across launches and overrides plist/manifest defaults, so a device that
/// switched flavors self-corrects; docs/resume-prompt.md M1.3). Symmetric with
/// `initializeFirebase`; called only by the flavor entrypoints after Firebase
/// is initialized, because the adapter touches a method channel and throws in
/// the plain test VM. Goes through the concrete adapter so `firebase_crashlytics`
/// stays imported in exactly one file.
///
/// FAIL-OPEN (ADR-039). This runs inside the pre-first-frame `.wait` of both
/// entrypoints, so a throw here used to propagate out of `main()` as a
/// `ParallelWaitError` — `runApp` was never reached and the app sat on the iOS
/// launch image forever, with no error, no frame, and (the sharp edge) no crash
/// report, because the reporter is exactly what failed. Crash reporting is
/// diagnostics: losing it must cost diagnostics, never the app. A failure
/// downgrades to [NoopCrashReporter], which still presents framework errors to
/// the console.
Future<CrashReporter> initializeCrashlytics(AppConfig config) async {
  final reporter = CrashlyticsCrashReporter();
  try {
    await reporter.setCollectionEnabled(config.flavor == AppFlavor.prod);
  } catch (failure) {
    debugPrint('Crashlytics unavailable, continuing without it: $failure');
    return const NoopCrashReporter();
  }
  return reporter;
}
