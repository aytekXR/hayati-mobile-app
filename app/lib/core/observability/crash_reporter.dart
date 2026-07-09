import 'package:flutter/foundation.dart';

/// VM-testable crash-reporting seam (docs/resume-prompt.md M1.3). Takes only
/// framework/Dart types — never a Firebase type — so tests and any future
/// non-`data` caller stay off the Crashlytics method channel;
/// [CrashlyticsCrashReporter] is the single adapter that binds it to Firebase.
abstract interface class CrashReporter {
  /// Records a Flutter framework error. The adapter presents the details to the
  /// console itself, so callers must not also chain the previous
  /// [FlutterError.onError] handler (that double-prints).
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });

  /// Records a non-framework/async error, e.g. one caught by
  /// `PlatformDispatcher.instance.onError`.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  });

  /// Appends a breadcrumb message carried by the next crash report.
  Future<void> log(String message);

  /// Associates subsequent reports with a user identifier.
  Future<void> setUserIdentifier(String identifier);
}
