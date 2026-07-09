import '../config/app_config.dart';
import 'crash_reporter.dart';
import 'crashlytics_crash_reporter.dart';

/// Constructs the Crashlytics-backed [CrashReporter] and applies the per-flavor
/// collection policy — dev OFF, prod ON — via the runtime API (which persists
/// across launches and overrides plist/manifest defaults, so a device that
/// switched flavors self-corrects; docs/resume-prompt.md M1.3). Symmetric with
/// `initializeFirebase`; called only by the flavor entrypoints after Firebase
/// is initialized, because the adapter touches a method channel and throws in
/// the plain test VM. Goes through the concrete adapter so `firebase_crashlytics`
/// stays imported in exactly one file.
Future<CrashReporter> initializeCrashlytics(AppConfig config) async {
  final reporter = CrashlyticsCrashReporter();
  await reporter.setCollectionEnabled(config.flavor == AppFlavor.prod);
  return reporter;
}
