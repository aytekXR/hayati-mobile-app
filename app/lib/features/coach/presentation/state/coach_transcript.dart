import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../domain/coach_persona.dart';
import '../../domain/coach_reply.dart';
import '../../domain/coach_transcript_entry.dart';

part 'coach_transcript.g.dart';

/// The in-memory state of ONE persona conversation (ADR-017 Decisions 2/3/6/8):
/// the confirmed [entries], the [helpSticky] latch, and the display-only
/// [lastRemaining] quota hint. Immutable, value semantics, `const` initial.
///
/// No-content rule (ADR-017 Decision 5): [toString] omits transcript text
/// (renders entry COUNT only) — this state could escape into Crashlytics via the
/// error hooks. Equality compares entries deeply (value semantics).
class CoachTranscriptState {
  const CoachTranscriptState({
    this.entries = const [],
    this.helpSticky = false,
    this.lastRemaining,
  });

  /// The confirmed turns, oldest-first. Appended only on a successful send
  /// (server-ack discipline — no optimistic UI, ADR-017 Decision 8).
  final List<CoachTranscriptEntry> entries;

  /// The help-sticky latch (Decision 2 rule 3): set whenever ANY response
  /// arrives with `kind:'help'`, cleared ONLY by [reset]. While latched the UI
  /// pauses the conversation and no further sends may issue.
  final bool helpSticky;

  /// The last response's quota hint, or null before the first hint-bearing
  /// response (Decision 6). Updated only when a response CARRIES `remaining`.
  final CoachRemaining? lastRemaining;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachTranscriptState &&
          _sameEntries(other.entries, entries) &&
          other.helpSticky == helpSticky &&
          other.lastRemaining == lastRemaining;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(entries), helpSticky, lastRemaining);

  @override
  String toString() =>
      'CoachTranscriptState(entries: ${entries.length}, '
      'helpSticky: $helpSticky, lastRemaining: $lastRemaining)';

  static bool _sameEntries(
    List<CoachTranscriptEntry> a,
    List<CoachTranscriptEntry> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One persona conversation's transcript (ADR-017 Decisions 2/3/6/8), a
/// `keepAlive` family keyed by `(uid, coupleId, personaId)` (Decision 3):
/// ephemeral in-memory, survives route pop/re-push and a mid-send controller
/// disposal, cleared on app restart, and keyed by `uid` so a second account on
/// the device gets fresh state. Never persists conversation content anywhere.
@Riverpod(keepAlive: true)
class CoachTranscript extends _$CoachTranscript {
  @override
  CoachTranscriptState build(
    String uid,
    String coupleId,
    CoachPersonaId personaId,
  ) => const CoachTranscriptState();

  /// Appends a confirmed exchange (ADR-017 Decision 8): the user turn plus the
  /// response entry land together. A `kind:'reply'` becomes a [CoachPersonaTurn];
  /// a `kind:'help'` becomes a [CoachHelpTurn] AND latches [helpSticky] (Decision
  /// 2 — the latch never un-sets). [lastRemaining] updates ONLY when the reply
  /// carries `remaining` (Decision 6 — a hint-less response leaves the prior
  /// value untouched).
  void applyExchange({required String userText, required CoachReply reply}) {
    // The OWNER guard (ADR-017 Decision 3; S019 post-implementation review's
    // confirmed find): a sign-out landing MID-SEND races the captured-notifier
    // append. The root listener's family invalidation is LAZY on a keepAlive
    // element (no dispose, recompute-on-next-read) — and this very append would
    // BE that next read, silently re-populating the wiped conversation with the
    // in-flight turn (crisis text included) and serving it to the next same-uid
    // sign-in in this process. So a late exchange lands ONLY while its owner is
    // still the signed-in user; otherwise it is dropped — the conversation is
    // being torn down anyway. A mid-send PERSONA SWITCH leaves auth untouched,
    // so Decision 8's paid-for reply still lands in that case.
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn || auth.user.uid != uid) return;
    final responseEntry = switch (reply.kind) {
      CoachReplyKind.reply => CoachPersonaTurn(reply.text),
      CoachReplyKind.help => CoachHelpTurn(reply.text, category: reply.category),
    };
    state = CoachTranscriptState(
      entries: [...state.entries, CoachUserTurn(userText), responseEntry],
      helpSticky: state.helpSticky || reply.kind == CoachReplyKind.help,
      lastRemaining: reply.remaining ?? state.lastRemaining,
    );
  }

  /// The explicit "new conversation" affordance (ADR-017 Decision 2 rule 4):
  /// clears this persona's entries, its latch, and its quota hint — back to the
  /// `const` initial state. Other personas' conversations are untouched (family
  /// isolation).
  void reset() {
    state = const CoachTranscriptState();
  }
}
