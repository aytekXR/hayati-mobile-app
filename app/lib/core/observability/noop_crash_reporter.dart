import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// The [CrashReporter] used when Crashlytics could not be initialized (ADR-039).
///
/// It exists so a reporting failure degrades reporting ONLY — never the boot.
/// `initializeCrashlytics` returns this instead of throwing, and `runHayati`
/// installs the same process-global hooks over it, so the two error paths keep
/// exactly one owner.
///
/// **It still PRESENTS framework errors to the console.** `installErrorHooks`
/// replaces `FlutterError.onError`, and the real adapter presents the details
/// itself (which is why the hook deliberately does not chain the previous
/// handler). A no-op that only swallowed would therefore make every framework
/// error vanish from the log on exactly the boots that already went wrong — the
/// worst possible moment to go quiet.
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    FlutterError.presentError(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    debugPrint('Unreported error (no crash reporter): $error\n$stack');
  }

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserIdentifier(String identifier) async {}
}
