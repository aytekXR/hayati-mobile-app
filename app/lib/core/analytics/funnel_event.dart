/// Which of the three emitters owns an event (ADR-057 Decision 1).
///
/// `architecture.md` §7 reads as one stream of twelve names. It is not one
/// stream, and revision 1 of ADR-057 drew only the first of these two lines.
enum AnalyticsEmitter {
  /// The app emits it. Every one of these has a call site under
  /// `app/lib/features/` (or `app/lib/app.dart`), asserted by
  /// `funnel_call_site_sentinel_test.dart`.
  client,

  /// The RevenueCat webhook's to emit, not the app's: the app learns about
  /// entitlement from a mirror, so a client `paid` would timestamp the moment
  /// the phone noticed rather than the moment money moved — and would be
  /// missing entirely for a user who never reopens the app after purchasing.
  ///
  /// **The server emitter does not exist** (#242): `functions/src/` carries no
  /// analytics emission of any kind and ADR-013's scope does not include it.
  server,

  /// The feature does not exist and is not in the MVP — `mvp.md`'s OUT list:
  /// *"Quizzes & shareable result cards (v1.5)"*.
  ///
  /// Named rather than omitted so its absence is a recorded decision instead of
  /// an unwired funnel step that reads as forgotten forever.
  notBuilt,
}

/// The CLOSED funnel vocabulary of `docs/architecture.md` §7 (ADR-057 D1).
///
/// [wire] is the analytics event name exactly as §7 spells it, and
/// `funnel_event_sentinel_test.dart` compares this whole set against that
/// document in BOTH directions — an event added to §7 and an event deleted from
/// it are equally red.
///
/// **`q_answered{solo|mutual}` is ONE name here, not two.** The brace in §7 is
/// alternation over a dimension ([QAnsweredEvent.mode]); reading it as two event
/// names would put a value into a name, which is the thing the payload types
/// exist to prevent.
enum FunnelEvent {
  install('install', AnalyticsEmitter.client),
  signup('signup', AnalyticsEmitter.client),
  inviteSent('invite_sent', AnalyticsEmitter.client),
  paired('paired', AnalyticsEmitter.client),
  qAnswered('q_answered', AnalyticsEmitter.client),
  revealViewed('reveal_viewed', AnalyticsEmitter.client),
  streakDay('streak_day', AnalyticsEmitter.client),
  coachMsg('coach_msg', AnalyticsEmitter.client),
  trialStart('trial_start', AnalyticsEmitter.server),
  paid('paid', AnalyticsEmitter.server),
  churn('churn', AnalyticsEmitter.server),
  shareCardCreated('share_card_created', AnalyticsEmitter.notBuilt);

  const FunnelEvent(this.wire, this.emitter);

  /// The §7 event name. `.name` cannot be this (a Dart identifier admits no
  /// underscore-separated wire spelling without diverging from lowerCamelCase),
  /// so the wire string is explicit — the `CoachRegister.wire` precedent.
  final String wire;

  /// Which emitter owns it (ADR-057 D1).
  final AnalyticsEmitter emitter;

  /// The Dart payload class name for a client event, DERIVED from [wire] rather
  /// than hand-mapped: `q_answered` → `QAnsweredEvent`.
  ///
  /// This is deliberately a computation and not a field. A hand-written map
  /// between the vocabulary and the payload types would be a fixture derived
  /// from its own subject — it could not detect the drift it exists to detect
  /// (`session-lessons.md`, standing). `funnel_call_site_sentinel_test.dart`
  /// uses this to find call sites in the source tree.
  String get payloadTypeName => '${_pascalCase}Event';

  /// The [Analytics] method that emits this event, DERIVED from [wire] for the
  /// same reason [payloadTypeName] is: `q_answered` → `qAnswered`.
  ///
  /// `funnel_call_site_sentinel_test.dart` scans the source tree for
  /// `.<emitterMethodName>(` — the `card_surface_sentinel_test` idiom of asking
  /// the tree rather than trusting a list.
  String get emitterMethodName =>
      _pascalCase[0].toLowerCase() + _pascalCase.substring(1);

  String get _pascalCase => wire
      .split('_')
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();
}
