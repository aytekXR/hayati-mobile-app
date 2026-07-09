import 'package:flutter/foundation.dart';
import 'package:hayati_app/core/observability/crash_reporter.dart';

/// Hand-written fake backing the observability tests, mirroring
/// [FakeAuthRepository]'s record-into-lists style. Every call is captured so a
/// test can assert on the forwarded arguments; nothing touches a Firebase
/// channel, so it constructs and runs in the plain VM.
class FakeCrashReporter implements CrashReporter {
  final List<({FlutterErrorDetails details, bool fatal})> flutterErrors = [];
  final List<({Object error, StackTrace? stack, bool fatal})> errors = [];
  final List<String> logs = [];
  final List<String> userIdentifiers = [];

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    flutterErrors.add((details: details, fatal: fatal));
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    errors.add((error: error, stack: stack, fatal: fatal));
  }

  @override
  Future<void> log(String message) async {
    logs.add(message);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    userIdentifiers.add(identifier);
  }
}
