import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// Installs the two process-global error hooks, routing both to [reporter]
/// (docs/resume-prompt.md M1.3). Called from `runHayati` only when a reporter
/// is supplied, so widget tests that build `HayatiApp` directly stay off the
/// Crashlytics channel.
void installErrorHooks(CrashReporter reporter) {
  // recordFlutterError presents the details to the console itself, so the
  // previous handler is deliberately NOT chained — chaining double-prints every
  // framework error.
  FlutterError.onError = (details) =>
      reporter.recordFlutterError(details, fatal: true);
  // Catch-all for async/platform errors outside the framework. Returning true
  // marks the error handled (dart:ui ErrorCallback contract).
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.recordError(error, stack, fatal: true);
    return true;
  };
}
