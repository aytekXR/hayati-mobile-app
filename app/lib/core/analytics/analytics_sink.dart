import 'analytics_dimensions.dart';
import 'analytics_event.dart';

/// Where a funnel event goes (ADR-057 Decision 2).
///
/// The `CrashReporter` idiom one folder over: a port taking only app-owned
/// types — never a vendor type — so exactly one adapter would ever bind it to an
/// SDK, and tests stay off any method channel.
///
/// **[record] returns `void`, deliberately.** Telemetry must never be awaited
/// into a user-visible path, and a `Future` return is an invitation to do
/// exactly that. The `PushDiagnosticRecorder` rule applies with the same force:
/// **implementations never throw** — a failure is silence, never a frame the
/// user sees (ADR-039 D1).
///
/// **No vendor adapter ships in this slice.** Mixpanel needs a project token the
/// founder must supply; Firebase Analytics would be a new package. Both belong
/// behind this interface, and the moment either lands, `docs/legal/` and
/// `docs/dpa-inventory.md`'s processor register both need a row — see ADR-057's
/// Consequences and #226. That gate is a paragraph, not a test.
abstract interface class AnalyticsSink {
  /// Records [event] with the §7 [dimensions] attached. Never throws.
  void record(AnalyticsEvent event, AnalyticsDimensions dimensions);
}

/// The sink that records nothing — and the DEFAULT the port resolves to.
///
/// This is what prod ships until a vendor adapter exists, and what every test
/// and every un-overridden container gets. It is a deliberate departure from the
/// `authRepositoryProvider` idiom of throwing when unoverridden, and the reason
/// is worth stating because the departure will otherwise read as an oversight:
/// those seams throw because a missing repository is a bug that must be loud.
/// **This is telemetry.** `NoopCrashReporter` exists so "a reporting failure
/// degrades reporting ONLY — never the boot", and a throwing base here would
/// take every widget test that renders an instrumented screen red — the trap
/// `push_diagnostic_recorder_provider.dart` records having already been sprung
/// once ("an unguarded resolve here would take 60 unrelated widget tests red").
class NoopAnalyticsSink implements AnalyticsSink {
  const NoopAnalyticsSink();

  @override
  void record(AnalyticsEvent event, AnalyticsDimensions dimensions) {}
}
