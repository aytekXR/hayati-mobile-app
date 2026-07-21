import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/motion_tokens.dart';
import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../coach/presentation/coach_screen.dart';
import '../../entitlements/presentation/pack_selection_screen.dart';
import '../../entitlements/presentation/premium_gate.dart';
import '../../entitlements/presentation/state/entitlement_providers.dart';
import '../../settings/presentation/widgets/settings_gear_overlay.dart';
import '../domain/couple.dart';
import '../domain/couple_answer.dart';
import '../domain/couple_data_exception.dart';
import '../domain/couple_day.dart';
import '../domain/question.dart';
import '../domain/question_pack_repository.dart';
import '../domain/solo_clock.dart';
import 'state/paired_answer_controller.dart';
import 'state/paired_providers.dart';
import 'state/partner_slot.dart';

/// The paired couple's home (M3.3, docs/architecture.md §3/§4): today's
/// server-assigned question with the answer entry and the mutual-reveal
/// partner slot. Replaces the M2.3 placeholder in `OnboardingGate`.
///
/// Read path: `couples/{coupleId}` (timezone) → [coupleDayKey] over the
/// STORED zone (ADR-011 — never the device zone) → `days/{dayKey}`
/// (assignment metadata) → question text from the bundled pack by
/// `packId`+`questionId`. A missing day doc is the honest no-day-yet state:
/// the server assignment is authoritative and streams in live when the
/// hourly rollover lands it.
///
/// The reveal is enforced server-side (rules); the client mirror is
/// `partnerSlotProvider`, which never watches the partner's answer until
/// the own answer is server-acked. Once both answers exist the day is
/// revealed AND frozen (rules deny further edits), so the entry collapses
/// into a read-only own-answer card.
///
/// The dayKey is computed per build from `soloClockProvider` (the app's one
/// clock seam). Unlike solo, a stale day here is a stale SHARED state, so
/// the screen also recomputes on app resume ([WidgetsBindingObserver]) —
/// the dominant path back after a midnight rollover; a timer is still
/// deliberately avoided (ADR-009 precedent).
class PairedHomeScreen extends ConsumerStatefulWidget {
  const PairedHomeScreen({
    super.key,
    required this.uid,
    required this.coupleId,
  });

  final String uid;

  /// From the gate's settled profile (`users/{uid}.coupleId`, non-null on
  /// this route).
  final String coupleId;

  @override
  ConsumerState<PairedHomeScreen> createState() => _PairedHomeScreenState();
}

class _PairedHomeScreenState extends ConsumerState<PairedHomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foregrounding after the couple's midnight must show the new day: no
    // stream on the OLD dayKey will ever emit again (the rollover writes a
    // different doc id), so the rebuild — which recomputes dayKey from the
    // clock — is triggered here.
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // ONE wrap over the whole build (ADR-018 Decision 7; review finding
    // DVUX-7): this screen returns a different Scaffold per state, so the
    // settings gear cannot live "in the SafeArea" of any one of them. Wrapping
    // the return puts it in EVERY state — including the error state, where a
    // user whose couple stream is broken must still be able to reach the lock.
    return SettingsGearOverlay(uid: widget.uid, child: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    // Same layered AsyncValue settling idiom as SoloHomeScreen: each layer
    // is data the next one keys on, so precedence is structural.
    final couple = ref.watch(coupleProvider(widget.coupleId));
    if (couple.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final coupleError = couple.error;
    if (coupleError != null) {
      return _PairedErrorView(
        detail: (l10n) => coupleError is CoupleDataNetworkException
            ? l10n.errorNetworkRetry
            : l10n.errorGeneric,
        onRetry: () => ref.invalidate(coupleProvider(widget.coupleId)),
      );
    }
    final coupleData = couple.value;
    final partnerUid = coupleData?.partnerUidFor(widget.uid);
    if (coupleData == null || partnerUid == null) {
      // users.coupleId pointing at a missing couple, or at a couple this
      // uid is not a member of: corrupt state, surfaced honestly.
      return _PairedErrorView(
        detail: (l10n) => l10n.errorGeneric,
        onRetry: () => ref.invalidate(coupleProvider(widget.coupleId)),
      );
    }

    final String dayKey;
    try {
      // NEVER the device zone (ADR-011): the stored zone keys the day.
      dayKey = coupleDayKey(
        ref.watch(soloClockProvider)(),
        coupleData.timezone,
      );
    } on Object {
      // A stored zone the bundled tz db cannot resolve (corrupt doc or
      // tzdata skew): an honest error beats a guessed date — and it must
      // never throw INTO build (an unrecoverable red screen for both
      // members).
      return _PairedErrorView(
        detail: (l10n) => l10n.errorGeneric,
        onRetry: () => ref.invalidate(coupleProvider(widget.coupleId)),
      );
    }

    final day = ref.watch(coupleDayAssignmentProvider(widget.coupleId, dayKey));
    if (day.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final dayError = day.error;
    if (dayError != null) {
      return _PairedErrorView(
        detail: (l10n) => dayError is CoupleDataNetworkException
            ? l10n.errorNetworkRetry
            : l10n.errorGeneric,
        onRetry: () => ref.invalidate(
          coupleDayAssignmentProvider(widget.coupleId, dayKey),
        ),
      );
    }
    final assignment = day.value;
    if (assignment == null) {
      return const _NoDayYetView();
    }

    final pack = ref.watch(pairedQuestionPackProvider(assignment.packId));
    if (pack.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final packError = pack.error;
    if (packError != null) {
      if (packError is UnknownQuestionPackException) {
        return const _PackUpdateView();
      }
      return _PairedErrorView(
        detail: (l10n) => l10n.errorGeneric,
        onRetry: () =>
            ref.invalidate(pairedQuestionPackProvider(assignment.packId)),
      );
    }
    final question = pack.value!.questionById(assignment.questionId);
    if (question == null) {
      // The assignment references a question this bundle does not carry —
      // the deployed pack version outpaced the install (ADR-011 pack lag).
      return const _PackUpdateView();
    }

    final own = ref.watch(
      coupleAnswerProvider(widget.coupleId, dayKey, widget.uid),
    );
    if (own.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final ownError = own.error;
    if (ownError != null) {
      return _PairedErrorView(
        detail: (l10n) => ownError is CoupleDataNetworkException
            ? l10n.errorNetworkRetry
            : l10n.errorGeneric,
        onRetry: () => ref.invalidate(
          coupleAnswerProvider(widget.coupleId, dayKey, widget.uid),
        ),
      );
    }

    final slot = ref.watch(
      partnerSlotProvider(
        coupleId: widget.coupleId,
        dayKey: dayKey,
        ownUid: widget.uid,
        partnerUid: partnerUid,
      ),
    );

    return _PairedQuestionView(
      // Re-key on the day so a midnight flip re-seeds the entry controller
      // instead of carrying yesterday's draft into the new question.
      key: ValueKey(dayKey),
      uid: widget.uid,
      coupleId: widget.coupleId,
      dayKey: dayKey,
      question: question,
      persisted: own.value,
      slot: slot,
      // Live server truth off the couple doc (ADR-012); the revealed section
      // shows it only when it is a real, positive streak.
      streak: coupleData.streak,
    );
  }
}

/// The question card: entry + partner slot. Own answer editable until the
/// reveal (rules freeze both docs once both exist).
class _PairedQuestionView extends ConsumerStatefulWidget {
  const _PairedQuestionView({
    super.key,
    required this.uid,
    required this.coupleId,
    required this.dayKey,
    required this.question,
    required this.persisted,
    required this.slot,
    required this.streak,
  });

  final String uid;
  final String coupleId;
  final String dayKey;
  final Question question;

  /// The day's persisted own answer (live), or null while unanswered. Seeds
  /// the entry ONCE (same never-clobber rule as the solo entry).
  final CoupleAnswer? persisted;

  final PartnerSlot slot;

  /// The couple's live streak (ADR-012). Rendered only in the revealed state,
  /// and only when [CoupleStreak.count] > 0 (see [build]).
  final CoupleStreak streak;

  @override
  ConsumerState<_PairedQuestionView> createState() =>
      _PairedQuestionViewState();
}

class _PairedQuestionViewState extends ConsumerState<_PairedQuestionView> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.persisted?.text ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// At-most-once-per-instance guard for the reveal haptic. Reset with the
  /// State — and the State is re-keyed per dayKey (parent's ValueKey), so a new
  /// day can buzz again.
  bool _revealHapticFired = false;

  @override
  void didUpdateWidget(covariant _PairedQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The signature reveal moment (brandkit §6, "gentle haptic"): a single
    // gentle buzz the first time the reveal LANDS, marked by the partner slot
    // going waiting→revealed. This is ONCE per instance and therefore once per
    // dayKey per app session.
    //
    // Honest bound, discovered in testing: this fires on cold-open-into-revealed
    // too, not only on the live "partner just answered" moment. The read chain
    // settles Locked→Waiting→Revealed even when both answers already exist, so
    // there is no cheap client signal that separates "the user was watching
    // Waiting" from "the app just loaded a revealed day" — both are genuinely
    // waiting→revealed. We choose the simple, §6-consistent behaviour (buzz once
    // when the reveal appears) over a timing heuristic or a persisted per-day
    // flag, which would add fragility for a marginal UX gain. App RESUME does
    // NOT re-fire: the State (and this flag) survive, and a resumed revealed day
    // is revealed→revealed, not waiting→revealed. The permission-denial self-heal
    // (locked→revealed) is likewise silent — not a waiting→revealed transition,
    // and the flag is already set. The soft-unfold MOTION is separate: it plays
    // on every revealed-group mount (see _RevealUnfold).
    //
    // Belt-and-suspenders, deliberately: `_revealHapticFired` is the at-most-once
    // guarantee, and the `oldWidget.slot is PartnerSlotWaiting` check documents
    // the intent (the reveal moment IS the partner answer arriving). They are
    // redundant by the state machine — the partner watch attaches only after the
    // own ack (Waiting), and a network Failure does not auto-retry
    // (`partnerSlotProvider`), so the ONLY path to first-Revealed is
    // Waiting→Revealed and every recovery (Locked/Failure→Revealed) can only
    // happen with the flag already set. That is why the guard's specificity is
    // inspection-verified rather than unit-tested: the transition that would
    // distinguish it from a broad `!Revealed→Revealed` guard is unreachable.
    if (!_revealHapticFired &&
        oldWidget.slot is PartnerSlotWaiting &&
        widget.slot is PartnerSlotRevealed) {
      _revealHapticFired = true;
      HapticFeedback.lightImpact();
    }
  }

  String get _entry => _controller.text.trim();

  bool get _saved =>
      widget.persisted != null && widget.persisted!.text == _entry;

  void _save() {
    unawaited(
      ref
          .read(pairedAnswerControllerProvider.notifier)
          .save(
            coupleId: widget.coupleId,
            dayKey: widget.dayKey,
            uid: widget.uid,
            questionId: widget.question.id,
            text: _entry,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final save = ref.watch(pairedAnswerControllerProvider);
    final saving = save is PairedSaveSaving;
    final revealed = widget.slot is PartnerSlotRevealed;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
              vertical: SpacingTokens.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.pairedQuestionTitle,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  widget.question.text,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x6),
                if (revealed)
                  // The reveal — the product (brandkit §9.3, "the reveal is the
                  // product; spend polish budget there"). The revealed group
                  // (streak + both answers) softly unfolds on entry (§6, "the
                  // signature interaction"); the gentle haptic is fired once by
                  // didUpdateWidget on the LIVE waiting→revealed transition, not
                  // here (this branch also mounts on cold-open-into-revealed).
                  // Own and partner render at EQUAL weight (brandkit §9.1, "two
                  // people, one screen state") and GROUPED (x4 — tighter than the
                  // x6 that sets the reveal apart from the affordances below), so
                  // the two answers read as one shared moment, not a list.
                  _RevealUnfold(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The mutual-day streak (M3.4, ADR-012): shown ONLY here
                        // and ONLY when count > 0 — a zero count renders nothing
                        // (reveal-trigger lag must never surface as a real
                        // streak), which is why the zero-streak revealed goldens
                        // carry no row.
                        if (widget.streak.count > 0) ...[
                          _StreakRow(count: widget.streak.count),
                          const SizedBox(height: SpacingTokens.x3),
                        ],
                        // Frozen by rules once both answered: read-only own card.
                        _AnswerCard(
                          label: l10n.pairedRevealedCaption,
                          text: widget.persisted?.text ?? _entry,
                        ),
                        // Grouped with the own card (x4). Rendered DIRECTLY (not
                        // via _PartnerSlotCard) because this branch is reached
                        // only when the slot is revealed.
                        const SizedBox(height: SpacingTokens.x4),
                        _AnswerCard(
                          label: l10n.pairedPartnerAnswerLabel,
                          text:
                              (widget.slot as PartnerSlotRevealed).answer.text,
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextField(
                    controller: _controller,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    // Hard cap at the rules ceiling — an over-length entry
                    // must be unrepresentable, not a server-denied dead end.
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(coupleAnswerMaxLength),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.pairedAnswerHint,
                    ),
                  ),
                  if (_saved) ...[
                    const SizedBox(height: SpacingTokens.x3),
                    Text(
                      l10n.pairedAnswerSavedCaption,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (save case PairedSaveFailure(:final failure)) ...[
                    const SizedBox(height: SpacingTokens.x3),
                    // Error copy in the theme's alert colour.
                    Text(
                      switch (failure) {
                        CoupleDataNetworkException() => l10n.errorNetworkRetry,
                        CoupleDataPermissionException() ||
                        CoupleDataUnknownException() => l10n.errorGeneric,
                      },
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.x6),
                  if (saving)
                    const FilledButton(
                      onPressed: null,
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: (_entry.isEmpty || _saved) ? null : _save,
                      child: Text(l10n.pairedAnswerSave),
                    ),
                  // The partner-slot status card (locked / waiting / failure)
                  // belongs to the non-revealed path ONLY — the revealed path
                  // renders the partner's answer inside the unfold group above.
                  // Its x6 spacer moved in here with it (it used to be an
                  // unconditional spacer below the if/else); co-locating both so
                  // the non-revealed column is byte-for-byte what it was:
                  // button → x6 → slot → x6 → packs.
                  const SizedBox(height: SpacingTokens.x6),
                  _PartnerSlotCard(slot: widget.slot),
                ],
                // The quiet packs affordance (ADR-014 Decision 4): mounted
                // INSIDE the question view only, so the daily loop's other
                // states (no_day_yet, pack-update, error, loading) carry no
                // tile and their goldens stay byte-identical. The x6 above is
                // the single unconditional gap before the affordances in EVERY
                // question-view state (reveal and non-reveal alike).
                const SizedBox(height: SpacingTokens.x6),
                _PacksTile(coupleId: widget.coupleId),
                // The quiet coach affordance (ADR-017 Decision 1): the tile AND
                // its inter-sibling spacer live INSIDE the gate's unlocked
                // subtree, so a free couple renders literally nothing — no
                // tile, no spacer, no pixel shift, and every existing free-tier
                // paired-home golden stays byte-identical.
                PremiumGate(
                  coupleId: widget.coupleId,
                  unlocked: Column(
                    children: [
                      const SizedBox(height: SpacingTokens.x6),
                      _CoachTile(uid: widget.uid, coupleId: widget.coupleId),
                    ],
                  ),
                  locked: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet packs entry point on the paired home (ADR-014 Decision 4): opens
/// [PackSelectionScreen] where the single [PremiumGate] lives — the tile itself
/// never re-decides. Watches the couple's `isPremium` for the free-tier lock
/// badge (clay, never gold) and the honest subtitle.
class _PacksTile extends ConsumerWidget {
  const _PacksTile({required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isPremium = ref.watch(isPremiumProvider(coupleId: coupleId));
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PackSelectionScreen(coupleId: coupleId),
        ),
      ),
      borderRadius: RadiusTokens.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.cardPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: RadiusTokens.cardRadius,
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories, color: theme.colorScheme.primary),
            const SizedBox(width: SpacingTokens.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.packsTileTitle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: SpacingTokens.x1),
                  Text(
                    isPremium
                        ? l10n.packsTileSubtitlePremium
                        : l10n.packsTileSubtitleFree,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!isPremium) ...[
              const SizedBox(width: SpacingTokens.x2),
              Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The quiet coach entry point on the paired home (ADR-017 Decision 1): opens
/// [CoachScreen] via the exported [showCoach] helper. Mounted INSIDE the gate's
/// unlocked subtree only (see [_PairedQuestionView.build]) — a free couple never
/// renders it, so the coach has zero free-tier surface. Mirrors the packs tile's
/// visual structure without a lock badge (this tile exists only when premium).
class _CoachTile extends StatelessWidget {
  const _CoachTile({required this.uid, required this.coupleId});

  final String uid;
  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => showCoach(context, uid: uid, coupleId: coupleId),
      borderRadius: RadiusTokens.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.cardPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: RadiusTokens.cardRadius,
        ),
        child: Row(
          children: [
            Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: SpacingTokens.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.coachTileTitle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: SpacingTokens.x1),
                  Text(
                    l10n.coachTileSubtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: SpacingTokens.x2),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The partner half of the pre-reveal card: **locked / waiting / failure**.
/// Since ADR-025 slice 2 the REVEALED case is rendered directly inside
/// [_PairedQuestionView]'s unfold group (so the two answers can be grouped and
/// animated together), so this widget is only ever mounted in the non-revealed
/// `else` branch. The `PartnerSlotRevealed` arm below is therefore not reached
/// from that call site; it is retained because `PartnerSlot` is a sealed class
/// (the switch must be exhaustive) and it keeps the widget defensively reusable
/// — an inline failure here still never takes down the whole screen.
class _PartnerSlotCard extends StatelessWidget {
  const _PartnerSlotCard({required this.slot});

  final PartnerSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return switch (slot) {
      PartnerSlotLocked() => _slotShell(
        theme,
        icon: Icons.lock_outline,
        text: l10n.pairedPartnerLocked,
      ),
      PartnerSlotWaiting() => _slotShell(
        theme,
        icon: Icons.hourglass_empty,
        text: l10n.pairedPartnerWaiting,
      ),
      // Not reached from _PairedQuestionView (revealed renders directly there);
      // kept for sealed-class exhaustiveness + defensive reuse.
      PartnerSlotRevealed(:final answer) => _AnswerCard(
        label: l10n.pairedPartnerAnswerLabel,
        text: answer.text,
      ),
      PartnerSlotFailure(:final failure) => _slotShell(
        theme,
        icon: Icons.error_outline,
        text: failure is CoupleDataNetworkException
            ? l10n.errorNetworkRetry
            : l10n.errorGeneric,
        error: true,
      ),
    };
  }

  Widget _slotShell(
    ThemeData theme, {
    required IconData icon,
    required String text,
    bool error = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: RadiusTokens.cardRadius,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: error ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: SpacingTokens.x3),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: error ? theme.colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A revealed answer (own or partner's) as a labeled card.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: RadiusTokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: SpacingTokens.x2),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Test seam for the reveal unfold: the [Opacity] whose value a widget test
/// samples mid-animation (the animation is transient, so no golden captures it).
@visibleForTesting
const revealUnfoldOpacityKey = ValueKey<String>('reveal-unfold-opacity');

/// The reveal's "soft unfold" (brandkit §6 — *the* signature interaction, the
/// one the brandkit says to "budget polish here first"): its child fades in and
/// gently rises, once, when it mounts (both on cold-open-into-revealed and on
/// the live waiting→revealed transition — it does not, and need not, tell the
/// two apart; the haptic that DOES is in [_PairedQuestionViewState]).
///
/// Motion values come from [MotionTokens] (§6's 150–300ms band, ease-out
/// entering). VERTICAL-only slide, so it is direction-neutral (no RTL mirror).
/// Reduce-motion → [Duration.zero]: the child appears settled, no fade, no rise.
/// At rest it is pixel-neutral (`Opacity(1)` + `Transform.translate(Offset.zero)`
/// both hit Flutter's no-op fast paths), so it changes NO settled golden — the
/// only golden delta in the reveal is the x4 grouping in [_PairedQuestionView].
/// `alwaysIncludeSemantics` keeps the revealed content in the semantics tree
/// from the first frame, so a screen reader never loses it mid-unfold
/// (Appendix A, "screen-reader order matches visual order").
class _RevealUnfold extends StatelessWidget {
  const _RevealUnfold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : MotionTokens.revealUnfold,
      curve: MotionTokens.enter,
      child: child,
      builder: (context, t, child) => Opacity(
        key: revealUnfoldOpacityKey,
        opacity: t,
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * MotionTokens.revealSlide),
          child: child,
        ),
      ),
    );
  }
}

/// The couple's mutual-day streak as a modest, centered row (M3.4, ADR-012 /
/// PRD F3). A display slot only — deliberately NOT a celebration screen (that
/// is M5 polish): no animation, no gold, just the pomegranate heart (the
/// couple's bond) and the localized "N-day streak" caption. The caller gates
/// on [count] > 0, so this never renders a zero streak.
class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: SpacingTokens.x2),
        // Flexible so a long localized/scaled caption wraps instead of
        // overflowing the centered row.
        Flexible(
          child: Text(
            l10n.pairedStreak(count),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// The rollover has not assigned today's doc yet (pre-first-rollover, the
/// ≤1h post-midnight window, or deploy lag). No retry button: the day watch
/// is live and streams the assignment in the moment it lands (ADR-011 — the
/// server is authoritative, the client never predicts).
class _NoDayYetView extends StatelessWidget {
  const _NoDayYetView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.pairedNoDayTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(l10n.pairedNoDayBody, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The assignment references a pack/question this install does not bundle:
/// the deployed Function outpaced the app. The remedy is an update, so no
/// retry affordance (hammering the same bundle cannot succeed).
class _PackUpdateView extends StatelessWidget {
  const _PackUpdateView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.pairedPackUpdateTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(l10n.pairedPackUpdateBody, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settled failure (couple, day, pack, or own-answer stream) with retry.
class _PairedErrorView extends StatelessWidget {
  const _PairedErrorView({required this.detail, required this.onRetry});

  final String Function(AppLocalizations l10n) detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error copy in the theme's alert colour (alert-on-night OK).
                Text(
                  detail(l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
