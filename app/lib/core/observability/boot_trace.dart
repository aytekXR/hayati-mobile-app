import 'dart:developer' show Timeline;

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Debug-only cold-start stage recorder (ADR-022 Decision 5). The flavor
/// entrypoints call [mark] between the pre-frame bootstrap steps; the
/// `startup_timing_emulator_test` integration suite reads [marks] and prints the
/// per-stage table, and each mark also drops a `dart:developer` Timeline event so
/// a DevTools / Instruments trace lines up with the log.
///
/// NO-OP under `kReleaseMode`: prod pays nothing — no Stopwatch runs, the list
/// never grows, no Timeline call is made. Instrumentation gets the same
/// kill-switch discipline as Crashlytics collection (dev OFF / prod pays
/// nothing here at all).
///
/// The no-content rule (architecture §8) governs diagnostics too: a mark carries
/// a fixed STAGE NAME only — never a value, a uid, or anything a user typed. The
/// stage vocabulary is closed (the six constants below); do not pass data through
/// [mark].
abstract final class BootTrace {
  /// Started lazily on the first [mark]; measures elapsed-since-first-mark, not
  /// wall clock, so the table reads as offsets from `main`.
  static final Stopwatch _stopwatch = Stopwatch();

  static final List<BootStage> _marks = <BootStage>[];

  /// The recorded stages in order, oldest first. Empty in release. Unmodifiable:
  /// callers read, only [mark] appends.
  static List<BootStage> get marks => List.unmodifiable(_marks);

  /// Records [stage] at the current elapsed time and emits a matching Timeline
  /// instant event. A NO-OP under `kReleaseMode`. [stage] is a fixed name from
  /// the constants below — never data.
  static void mark(String stage) {
    if (kReleaseMode) return;
    if (!_stopwatch.isRunning) _stopwatch.start();
    _marks.add(BootStage(stage, _stopwatch.elapsed));
    Timeline.instantSync('BootTrace.$stage');
  }

  // The closed stage vocabulary — one per pre-frame bootstrap boundary
  // (ADR-022 Decision 1's critical path). Named, ordered, data-free.
  static const String stageMain = 'main';
  static const String stageFirebaseReady = 'firebaseReady';
  static const String stageAppCheckCrashlyticsReady =
      'appCheckCrashlyticsReady';
  static const String stageRcConfigured = 'rcConfigured';
  static const String stageLocalStateReady = 'localStateReady';
  static const String stageRunApp = 'runApp';
}

/// One recorded boot stage: a fixed [name] and the [elapsed] since the first
/// mark. A value type so the integration test can print and report it directly.
class BootStage {
  const BootStage(this.name, this.elapsed);

  final String name;
  final Duration elapsed;

  @override
  String toString() => '$name @ ${elapsed.inMilliseconds}ms';
}
