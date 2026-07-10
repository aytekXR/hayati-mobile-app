import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
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
      dayKey = coupleDayKey(ref.watch(soloClockProvider)(), coupleData.timezone);
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
        onRetry: () =>
            ref.invalidate(coupleDayAssignmentProvider(widget.coupleId, dayKey)),
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
  });

  final String uid;
  final String coupleId;
  final String dayKey;
  final Question question;

  /// The day's persisted own answer (live), or null while unanswered. Seeds
  /// the entry ONCE (same never-clobber rule as the solo entry).
  final CoupleAnswer? persisted;

  final PartnerSlot slot;

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
                if (revealed) ...[
                  // Frozen by rules once both answered: read-only own card.
                  _AnswerCard(
                    label: l10n.pairedRevealedCaption,
                    text: widget.persisted?.text ?? _entry,
                  ),
                ] else ...[
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
                ],
                const SizedBox(height: SpacingTokens.x6),
                _PartnerSlotCard(slot: widget.slot),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The partner half of the reveal: locked → waiting → revealed (or an
/// inline failure that never takes down the whole screen).
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
