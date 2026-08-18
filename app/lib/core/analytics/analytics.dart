import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/local_flag_store.dart';
import 'analytics_dimensions.dart';
import 'analytics_event.dart';
import 'analytics_sink.dart';

part 'analytics.g.dart';

/// Where events go. **Defaults to silence** (ADR-057 D2c) — not to a throw.
///
/// `main_dev.dart` overrides it with the `DebugAnalyticsSink`. `main_prod.dart`
/// deliberately does not: prod ships the no-op until a vendor adapter and the
/// founder's Mixpanel token exist. Tests get the no-op for free, which is why
/// instrumenting a screen cannot redden an unrelated widget test.
@Riverpod(keepAlive: true)
AnalyticsSink analyticsSink(Ref ref) => const NoopAnalyticsSink();

/// The §7 dimensions attached to every event (ADR-057 D3).
///
/// The BASE resolves the device locale and nothing else — correct for `install`
/// and `signup`, which fire before a profile exists. `app.dart` overrides it
/// with the profile-aware resolver, so a signed-in user's events carry the
/// register they actually chose. The override lives at the composition root
/// because nothing under `core/` may import `features/`.
@Riverpod(keepAlive: true)
AnalyticsDimensions analyticsDimensions(Ref ref) => AnalyticsDimensions(
  locale: analyticsLocaleFor(PlatformDispatcher.instance.locale.languageCode),
);

/// The app's funnel emitter (ADR-057).
@Riverpod(keepAlive: true)
Analytics analytics(Ref ref) => Analytics(ref);

/// Emits the client half of the `architecture.md` §7 funnel.
///
/// **One named method per client event, and the method owns the event's
/// idempotency key** (ADR-057 D4). This is the whole point of the shape: the
/// largest silent-wrongness risk in client funnel instrumentation is not what an
/// event carries but *how many times it fires* — an `install` that fires on
/// every cold boot is not an install, and a `paired` that fires on every
/// profile-stream tick is not a pairing. A call site cannot forget a key it
/// never had to supply.
///
/// **Nothing here can throw into a caller.** Every path is wrapped: a telemetry
/// failure degrades telemetry only (ADR-039 D1, the `NoopCrashReporter` and
/// `PushDiagnosticRecorder` doctrine). Call sites therefore need no guard of
/// their own, and none of them awaits anything.
class Analytics {
  const Analytics(this._ref);

  final Ref _ref;

  /// First launch on this device. Once per **device**.
  void install() => _emit(const InstallEvent(), onceKey: 'analytics.install');

  /// This account reached the app for the first time here. Once per **uid, per
  /// device** — a reinstall re-emits, which is the honest bound of a
  /// `SharedPreferences` key and is recorded in ADR-057 D4 rather than papered
  /// over. Closing it needs server-side identity (#243).
  void signup({required String uid}) =>
      _emit(const SignupEvent(), onceKey: 'analytics.signup.$uid');

  /// The invite share sheet was handed a composed message. **Per action** — a
  /// user who shares twice sent two invites.
  void inviteSent() => _emit(const InviteSentEvent());

  /// This user became half of a couple. Once per **uid+coupleId, per device**.
  ///
  /// Both partners' devices emit their own, so this counts **users paired**,
  /// never couples — the shape Gate 2 pays for (*"pairing ≥40% of signups"* is a
  /// per-user rate).
  void paired({required String uid, required String coupleId}) =>
      _emit(const PairedEvent(), onceKey: 'analytics.paired.$uid.$coupleId');

  /// A daily question was answered. Once per **uid+dayKey+mode, per device**, so
  /// editing an answer does not inflate the count.
  void qAnswered({
    required String uid,
    required String dayKey,
    required AnalyticsAnswerMode mode,
  }) => _emit(
    QAnsweredEvent(mode: mode),
    onceKey: 'analytics.q.$uid.$dayKey.${mode.name}',
  );

  /// The mutual reveal settled on screen. Once per **uid+dayKey, per device**:
  /// ADR-051's `_revealSignalFired` guard is per widget INSTANCE, so a re-open
  /// of the same day would otherwise emit again.
  void revealViewed({required String uid, required String dayKey}) => _emit(
    const RevealViewedEvent(),
    onceKey: 'analytics.reveal.$uid.$dayKey',
  );

  /// The couple's streak advanced to a new mutual day. Once per
  /// **uid+lastMutualDate, per device**; like [paired], both devices emit, so
  /// this counts user-streak-days rather than couple-days.
  void streakDay({
    required String uid,
    required String lastMutualDate,
    required int count,
  }) => _emit(
    StreakDayEvent(count: count),
    onceKey: 'analytics.streak.$uid.$lastMutualDate',
  );

  /// One coach turn. **Per send.** The ADR-016 crisis strip is applied by
  /// [CoachMsgEvent] itself, not here and not by the caller.
  void coachMsg({
    required AnalyticsCoachOutcome outcome,
    AnalyticsPersona? persona,
  }) => _emit(CoachMsgEvent(outcome: outcome, persona: persona));

  void _emit(AnalyticsEvent event, {String? onceKey}) {
    try {
      if (onceKey != null && !_claimOnce(onceKey)) return;
      _ref
          .read(analyticsSinkProvider)
          .record(event, _ref.read(analyticsDimensionsProvider));
    } on Object {
      // Telemetry never reaches a caller. There is deliberately no rethrow and
      // no reporter call here: a crash-reporter hop is the one thing ADR-057
      // D2(a) keeps analytics away from.
    }
  }

  /// Claims [key] for a once-only event; false if it was already claimed.
  ///
  /// `localFlagStoreProvider` THROWS when unoverridden (every widget test that
  /// does not wire storage), so the resolve is guarded — and on failure this
  /// **emits without de-duplication rather than not emitting**, the `PushTokenSync`
  /// guard precedent. Losing a de-dup is a counting error; losing the event is
  /// blindness, and blindness is what #239 exists to end.
  bool _claimOnce(String key) {
    final LocalFlagStore flags;
    try {
      flags = _ref.read(localFlagStoreProvider);
    } on Object {
      return true;
    }
    if (flags.isSet(key)) return false;
    unawaited(flags.set(key));
    return true;
  }
}
