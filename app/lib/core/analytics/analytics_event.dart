import 'package:flutter/foundation.dart' show immutable;

import 'funnel_event.dart';

/// Which half of the daily question an answer was (ADR-057 D1). §7's
/// `q_answered{solo|mutual}` is ONE event name with this dimension — the brace
/// is alternation over a value, and promoting a value into a name is exactly
/// what these types exist to stop.
enum AnalyticsAnswerMode { solo, mutual }

/// The three coach personas, mirrored from `CoachPersonaId` rather than
/// imported (`core/` does not depend on `features/`). The call site maps.
enum AnalyticsPersona { coach, dateGenie, giftGenie }

/// What a coach turn produced, as the CLIENT can observe it.
///
/// Deliberately coarser than the server's `CoachOutcome`, and it cannot be
/// otherwise: the wire response carries `kind: reply | help` (ADR-016 D1's
/// frozen discriminator), while the server distinguishes `crisis` (pre-scan)
/// from `help-path` (post-filter) — a distinction that never crosses the wire
/// because the pre-scan case never reaches a provider. Acceptable because the
/// ADR-016 stripping rule is identical for both; recorded so a later reader does
/// not go hunting for a resolution the wire does not carry.
enum AnalyticsCoachOutcome {
  reply,

  /// The safety path. A CRISIS outcome in ADR-016's sense: fields that could
  /// attribute it are dropped by [CoachMsgEvent].
  help,
}

/// One funnel event's typed payload (ADR-057 D3).
///
/// **Content is structurally excluded, not carefully omitted.**
/// `architecture.md` §8 promises event names carry no answer text *ever*, and a
/// promise kept by author discipline breaks the first time someone adds a
/// helpful field. So: a sealed hierarchy with one `final` subclass per client
/// event (the `AuthState` / `PartnerSlot` idiom), each declaring only fixed
/// fields drawn from closed enums or `int`. **There is no free-form map field
/// and no `String` field anywhere on this type**, so there is no place a
/// reflection could be put.
///
/// [debugFields] is a DERIVED, read-only projection for rendering and for
/// assertions — never a place to write to. `analytics_event_test.dart` asserts
/// no projected value is ever a `String`, so a `String` field added later is
/// caught by that test rather than by a user.
///
/// **No payload carries a uid or a `coupleId`, on any event, ever.** That is
/// stronger than ADR-016 requires — it forbids a uid, and forbids `coupleId`
/// only on crisis outcomes — and it is deliberate: this is a domestic-violence
/// aware product, and §8's own reasoning about coach *metadata* ("who tripped
/// the crisis detector; how often a partner uses the coach") applies to a funnel
/// keyed to a couple just as well. The cost is recorded in ADR-057 D7 and #243:
/// with no client-side identity, Gate 3's `install→paid` cannot be joined.
@immutable
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  /// The §7 name this payload carries.
  FunnelEvent get name;

  /// The typed fields, projected for rendering. Values are enums or `int`s by
  /// construction — never a `String` a user could have typed.
  Map<String, Object?> get debugFields => const <String, Object?>{};

  @override
  String toString() {
    final fields = debugFields;
    if (fields.isEmpty) return name.wire;
    final rendered = fields.entries
        .map((entry) => '${entry.key}: ${_render(entry.value)}')
        .join(', ');
    return '${name.wire}($rendered)';
  }

  static String _render(Object? value) => switch (value) {
    AnalyticsAnswerMode() => value.name,
    AnalyticsPersona() => value.name,
    AnalyticsCoachOutcome() => value.name,
    _ => '$value',
  };
}

/// First launch on this device (`install`). Once per device — ADR-057 D4.
final class InstallEvent extends AnalyticsEvent {
  const InstallEvent();

  @override
  FunnelEvent get name => FunnelEvent.install;
}

/// An account reached the app for the first time on this device (`signup`).
final class SignupEvent extends AnalyticsEvent {
  const SignupEvent();

  @override
  FunnelEvent get name => FunnelEvent.signup;
}

/// The invite share sheet was handed a composed message (`invite_sent`).
final class InviteSentEvent extends AnalyticsEvent {
  const InviteSentEvent();

  @override
  FunnelEvent get name => FunnelEvent.inviteSent;
}

/// This user became half of a couple (`paired`).
///
/// Keyed per uid by ADR-057 D4, so BOTH partners' devices emit their own: this
/// counts **users paired**, never couples. That is the shape Gate 2 pays for —
/// *"pairing ≥40% of **signups**"* is a per-user rate.
final class PairedEvent extends AnalyticsEvent {
  const PairedEvent();

  @override
  FunnelEvent get name => FunnelEvent.paired;
}

/// A daily question was answered (`q_answered`), in one of the two [mode]s.
final class QAnsweredEvent extends AnalyticsEvent {
  const QAnsweredEvent({required this.mode});

  final AnalyticsAnswerMode mode;

  @override
  FunnelEvent get name => FunnelEvent.qAnswered;

  @override
  Map<String, Object?> get debugFields => <String, Object?>{'mode': mode};
}

/// The mutual reveal settled on screen (`reveal_viewed`) — fired at ADR-051's
/// one-shot signal point, the same instant as the haptic and the announcement.
final class RevealViewedEvent extends AnalyticsEvent {
  const RevealViewedEvent();

  @override
  FunnelEvent get name => FunnelEvent.revealViewed;
}

/// The couple's streak advanced to a new mutual day (`streak_day`).
///
/// Like [PairedEvent] this is a couple-level fact keyed per uid, so it counts
/// **user-streak-days**, never couple-days (ADR-057 D4).
final class StreakDayEvent extends AnalyticsEvent {
  const StreakDayEvent({required this.count});

  /// The server-owned streak length after the advance (`CoupleStreak.count`).
  /// A count, never content.
  final int count;

  @override
  FunnelEvent get name => FunnelEvent.streakDay;

  @override
  Map<String, Object?> get debugFields => <String, Object?>{'count': count};
}

/// One coach turn (`coach_msg`) — the event ADR-016 binds.
///
/// The ADR-016 rule reproduced over the fields this type has: on a crisis
/// outcome ([AnalyticsCoachOutcome.help]) the [persona] is DROPPED even when one
/// is supplied, so "this couple asked persona X and hit the help path" cannot be
/// assembled. `coupleId` and uid are already absent from every event by
/// construction (see [AnalyticsEvent]), so [persona] is the only field left to
/// strip.
///
/// **Cap counts and the crisis category have no home on this type at all.** The
/// server response *does* return `remaining` on the post-filter help path
/// (ADR-016 D2), and `category` (`selfHarm` / `violence`) rides the help
/// response as display-only data — so an emitter that forwarded what it was
/// given would ship exactly the attribution ADR-016 forbids. Here it cannot
/// compile.
final class CoachMsgEvent extends AnalyticsEvent {
  const CoachMsgEvent({required this.outcome, AnalyticsPersona? persona})
    : _persona = persona;

  final AnalyticsCoachOutcome outcome;

  final AnalyticsPersona? _persona;

  /// The persona, or null on a crisis outcome — the ADR-016 strip, applied by
  /// the type rather than by every caller remembering to.
  AnalyticsPersona? get persona =>
      outcome == AnalyticsCoachOutcome.help ? null : _persona;

  @override
  FunnelEvent get name => FunnelEvent.coachMsg;

  @override
  Map<String, Object?> get debugFields => <String, Object?>{
    'outcome': outcome,
    if (persona != null) 'persona': persona,
  };
}
