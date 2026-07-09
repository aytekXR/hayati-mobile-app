import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// The single file in `lib/` that binds [CrashReporter] to Firebase
/// Crashlytics, mirroring the auth gateway/repository seam. Every method is a
/// razor-thin passthrough — all policy (flavor→collection toggle, hook wiring)
/// lives in VM-tested code — because these calls route through the
/// `plugins.flutter.io/firebase_crashlytics` method channel and are unrunnable
/// in the plain test VM (docs/resume-prompt.md M1.3).
class CrashlyticsCrashReporter implements CrashReporter {
  /// Defaults to `FirebaseCrashlytics.instance`, which requires a completed
  /// `Firebase.initializeApp` — so construct this only from the entrypoints
  /// (via `initializeCrashlytics`), never on a test path.
  CrashlyticsCrashReporter([FirebaseCrashlytics? crashlytics])
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  /// Applies the per-flavor collection policy. Not part of [CrashReporter] —
  /// it is a Crashlytics-only concern kept off the pure reporting seam — so
  /// `initializeCrashlytics` calls it on the concrete adapter.
  Future<void> setCollectionEnabled(bool enabled) =>
      _crashlytics.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) => _crashlytics.recordFlutterError(details, fatal: fatal);

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) => _crashlytics.recordError(error, stack, fatal: fatal);

  @override
  Future<void> log(String message) => _crashlytics.log(message);

  @override
  Future<void> setUserIdentifier(String identifier) =>
      _crashlytics.setUserIdentifier(identifier);
}
