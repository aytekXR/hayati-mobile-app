import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

import 'analytics_dimensions.dart';
import 'analytics_event.dart';
import 'analytics_sink.dart';

/// The dev-visible sink (ADR-057 Decision 2a): it writes ONE `debugPrint` line
/// per event, and it reaches nothing else.
///
/// **Why not "the existing observability layer".** `core/observability/` holds
/// exactly two candidates and both are wrong. `CrashReporter.log` is a
/// *Crashlytics breadcrumb* — collection is ON in prod (docs/architecture.md
/// §8), so routing events there would put product telemetry into crash reports
/// and hand an existing processor a data category `docs/dpa-inventory.md` does
/// not list for it. `BootTrace` is a closed six-constant boot-stage vocabulary,
/// not an event bus. So this sink is its own file, and
/// `analytics_sink_test.dart` asserts no file under `core/analytics/` so much as
/// names `CrashReporter`.
///
/// **A NO-OP under release** — `BootTrace`'s discipline (ADR-022 D5): *prod pays
/// nothing*. [releaseMode] is injected rather than read inline so the guard is
/// behaviourally testable instead of merely visible; its default is
/// `kReleaseMode` and a source assertion pins that default, because a default of
/// `false` would make every release build print and no test binary could observe
/// it.
///
/// Wired in `main_dev.dart` ONLY. Prod's entrypoint leaves the port at its
/// [NoopAnalyticsSink] default, so the two gates fail independently: the
/// `kReleaseMode` guard survives someone wiring this into the wrong entrypoint,
/// and the entrypoint wiring survives someone deleting the guard.
class DebugAnalyticsSink implements AnalyticsSink {
  const DebugAnalyticsSink({this.releaseMode = kReleaseMode});

  /// Whether this is a release build. Injected for testability; defaults to
  /// `kReleaseMode`.
  final bool releaseMode;

  @override
  void record(AnalyticsEvent event, AnalyticsDimensions dimensions) {
    if (releaseMode) return;
    debugPrint('analytics: $event $dimensions');
  }
}
