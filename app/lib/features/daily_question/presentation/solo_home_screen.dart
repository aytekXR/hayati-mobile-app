import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/design_system/typography_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/seed_week_row.dart';
import '../../../core/widgets/slow_load_escape.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../pairing/presentation/invite_share_screen.dart';
import '../../profile/domain/relationship_profile.dart';
import '../../profile/presentation/state/profile_providers.dart';
import '../../settings/presentation/widgets/privacy_spotlight_card.dart';
import '../../settings/presentation/widgets/settings_gear_overlay.dart';
import '../domain/question.dart';
import '../domain/solo_answer.dart';
import '../domain/solo_answer_exception.dart';
import '../domain/solo_clock.dart';
import '../domain/solo_day.dart';
import 'state/solo_answer_controller.dart';
import 'state/solo_providers.dart';

/// The unpaired user's home (M2.4, docs/prd.md F1): the day-N solo reflection
/// question with an answer entry, and a PERSISTENT invite nudge on every
/// settled state — the app is honest that it's better together, and the share
/// flow stays one tap away. `OnboardingGate` mounts this as the unpaired
/// fallback (`coupleId` → pending invite → THIS), so pairing mid-solo
/// re-routes to the paired home automatically the moment `coupleId` lands on
/// the live profile stream.
///
/// Day N is anchored on the rules-enforced `users/{uid}.createdAt` server
/// stamp ([soloDayNumber], docs/adr/009); the wall clock comes from
/// `soloClockProvider` so tests pin it. The day is computed per build — a
/// user sitting on the screen across midnight sees the next day on their
/// next rebuild, deliberately not via a timer (docs/adr/009).
///
/// Day 8+ stops the cycle ([soloCycleComplete]): questions never repeat, and
/// the nudge becomes the PRIMARY action of a completed state.
class SoloHomeScreen extends ConsumerWidget {
  const SoloHomeScreen({super.key, required this.uid, required this.profile});

  final String uid;

  /// The settled profile the gate routed on: carries the content language
  /// (solo questions render in the profile's question language, not the UI
  /// locale) and the day-N anchor.
  final RelationshipProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ONE wrap over the whole build (ADR-018 Decision 7; review finding
    // DVUX-7): this screen returns a different Scaffold per state, so the
    // settings gear cannot live "in the SafeArea" of any one of them. Wrapping
    // the return puts it in EVERY state — including the error state, where a
    // user whose pack load is broken must still be able to reach the lock.
    return SettingsGearOverlay(uid: uid, child: _buildBody(context, ref));
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final now = ref.watch(soloClockProvider)();
    final day = soloDayNumber(anchor: profile.createdAt?.toLocal(), now: now);
    if (soloCycleComplete(day)) {
      return _SoloCompletedView(uid: uid);
    }

    // in-flight → spinner; settled error → retry view; settled data → the
    // day's question (same AsyncValue precedence idiom as InviteShareScreen).
    final pack = ref.watch(soloQuestionPackProvider(profile.contentLanguage));
    if (pack.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (pack.error != null) {
      return _SoloErrorView(
        uid: uid,
        detail: (l10n) => l10n.errorGeneric,
        onRetry: () =>
            ref.invalidate(soloQuestionPackProvider(profile.contentLanguage)),
      );
    }

    final dayKey = soloDayKey(now);
    final answer = ref.watch(soloAnswerProvider(uid, dayKey));
    // `soloAnswerProvider` is a Firestore DOCUMENT listener over
    // `users/{uid}/soloAnswers/{dayKey}` (FirestoreSoloAnswersRepository.
    // watchAnswer → `.snapshots()`) — the shape ADR-039 was written about: on a
    // device that cannot reach the backend with nothing cached it raises NO
    // event at all, not an empty snapshot and not an error, so `isLoading`
    // stays true indefinitely.
    //
    // This screen is NOT a dead end even so, and the distinction matters:
    // `SettingsGearOverlay` wraps every state of both homes deliberately
    // (ADR-018 D7), and settings renders its sign-out row unconditionally, so
    // the door exists. What did NOT exist was any indication that anything was
    // wrong — an indefinite silent spinner, on the screen every solo user
    // occupies until their partner installs. So this is ADR-039's threshold
    // pattern for its stated reason ("correct for the first second and a trap
    // thereafter"), with RETRY ONLY: the escape differs by surface, and
    // sign-out here would duplicate the gear two inches above it.
    //
    // The pack load above is a `rootBundle` asset read and stays a plain
    // spinner on purpose: it cannot hang on a network it never touches.
    if (answer.isLoading) {
      return SlowLoadEscape(
        actions: [
          FilledButton(
            onPressed: () => ref.invalidate(soloAnswerProvider(uid, dayKey)),
            child: Text(AppLocalizations.of(context).tryAgain),
          ),
        ],
      );
    }
    final answerError = answer.error;
    if (answerError != null) {
      return _SoloErrorView(
        uid: uid,
        detail: (l10n) => answerError is SoloAnswerNetworkException
            ? l10n.errorNetworkRetry
            : l10n.errorGeneric,
        onRetry: () => ref.invalidate(soloAnswerProvider(uid, dayKey)),
      );
    }

    // The pack passed the load-time exactly-7 check and the day is in-cycle,
    // so a question always exists here.
    final question = soloQuestionForDay(pack.value!, day)!;
    return _QuestionView(
      uid: uid,
      dayKey: dayKey,
      day: day,
      question: question,
      persisted: answer.value,
    );
  }
}

/// Days 1-7: nudge banner, day progress, the question, and the answer entry.
class _QuestionView extends ConsumerStatefulWidget {
  const _QuestionView({
    required this.uid,
    required this.dayKey,
    required this.day,
    required this.question,
    required this.persisted,
  });

  final String uid;
  final String dayKey;
  final int day;
  final Question question;

  /// The day's persisted answer (live from `soloAnswerProvider`), or null
  /// while unanswered. Seeds the entry field ONCE — after a save the stream
  /// echoes exactly what was typed, and a mid-edit remote overwrite (another
  /// device editing the same solo day) deliberately never clobbers local
  /// typing.
  final SoloAnswer? persisted;

  @override
  ConsumerState<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends ConsumerState<_QuestionView> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.persisted?.text ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The canonical entry the save persists and the saved-caption compares:
  /// surrounding whitespace never counts as a change.
  String get _entry => _controller.text.trim();

  bool get _saved =>
      widget.persisted != null && widget.persisted!.text == _entry;

  void _save() {
    unawaited(
      ref
          .read(soloAnswerControllerProvider.notifier)
          .save(
            uid: widget.uid,
            dayKey: widget.dayKey,
            questionId: widget.question.id,
            text: _entry,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final save = ref.watch(soloAnswerControllerProvider);
    final saving = save is SoloSaveSaving;
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
                // The one-time privacy spotlight (redesign M-6) atop the first
                // home — renders nothing once handled, so it mounts
                // unconditionally and the day-question layout below is
                // byte-identical for every returning user.
                PrivacySpotlightCard(uid: widget.uid),
                _InviteNudgeCard(uid: widget.uid),
                const SizedBox(height: SpacingTokens.x6),
                Text(
                  l10n.soloDayProgress(widget.day),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x2),
                // The caption's own sentence, drawn (QW-9). Position in the
                // seven-day cycle, never a claim about which days were
                // answered — see [SeedWeekRow].
                SeedWeekRow(day: widget.day),
                const SizedBox(height: SpacingTokens.x3),
                // CONTENT: the solo pack follows `contentLanguage`, which the
                // user picks independently of the interface language.
                //
                // The Question style (QW-3), not `headlineMedium`: this is the
                // same hero text the paired home and the partner preview
                // already render at 28/300, and it was the only one of the
                // three still sharing H1 with screen titles — so the product's
                // hero sentence changed voice depending on whether you had a
                // partner yet.
                ContentText(
                  widget.question.text,
                  style: TypographyTokens.questionStyleFor(
                    Localizations.localeOf(context).languageCode,
                  ).copyWith(color: theme.colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x6),
                TextField(
                  controller: _controller,
                  enabled: !saving,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  // Hard cap at the rules ceiling (review finding, Session
                  // 010): without it an over-length entry reaches Firestore,
                  // is rules-denied and dead-ends in the generic error copy.
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(soloAnswerMaxLength),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: l10n.soloAnswerHint),
                ),
                if (_saved) ...[
                  const SizedBox(height: SpacingTokens.x3),
                  Text(
                    l10n.soloAnswerSavedCaption,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (save case SoloSaveFailure(:final failure)) ...[
                  const SizedBox(height: SpacingTokens.x3),
                  // Error copy in the theme's alert colour (alert-on-night OK).
                  Text(
                    switch (failure) {
                      SoloAnswerNetworkException() => l10n.errorNetworkRetry,
                      SoloAnswerPermissionException() ||
                      SoloAnswerUnknownException() => l10n.errorGeneric,
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
                    // Disabled while there is nothing new to persist: empty
                    // entry, or the entry already matches the saved answer.
                    onPressed: (_entry.isEmpty || _saved) ? null : _save,
                    child: Text(l10n.soloAnswerSave),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Day 8+: the cycle stopped — questions never repeat — and the invite is
/// the honest primary action (docs/adr/009).
class _SoloCompletedView extends StatelessWidget {
  const _SoloCompletedView({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
              children: [
                Text(
                  l10n.soloCompletedTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(l10n.soloCompletedBody, textAlign: TextAlign.center),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(
                  onPressed: () => _openInviteShare(context, uid),
                  child: Text(l10n.soloNudgeAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settled failure (pack asset or answer stream) with retry — the nudge stays
/// visible even here (the acceptance contract: every solo state carries it).
class _SoloErrorView extends StatelessWidget {
  const _SoloErrorView({
    required this.uid,
    required this.detail,
    required this.onRetry,
  });

  final String uid;
  final String Function(AppLocalizations l10n) detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                _InviteNudgeCard(uid: uid),
                const SizedBox(height: SpacingTokens.x6),
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

/// The persistent "better together" banner (docs/prd.md F1, brandkit §7:
/// invitational, never guilt-tripping). Secondary affordance on question days
/// — the day's answer stays the one primary action per screen.
class _InviteNudgeCard extends StatelessWidget {
  const _InviteNudgeCard({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: RadiusTokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.soloNudgeBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: SpacingTokens.x2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => _openInviteShare(context, uid),
              child: Text(l10n.soloNudgeAction),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushes the share flow over the gate-mounted solo home. The wrapper pops
/// itself the moment the live profile carries a `coupleId` — the partner
/// joined while the user sat on the pushed share screen — uncovering the
/// gate, which has already re-routed to the paired home underneath (the same
/// pop-on-success idiom as the partner preview's `_JoinActions`).
void _openInviteShare(BuildContext context, String uid) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => _PushedInviteShare(uid: uid)));
}

class _PushedInviteShare extends ConsumerWidget {
  const _PushedInviteShare({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Collapse the WHOLE pushed stack back onto the gate, never a bare
    // pop(): the share screen's "Have a code?" pushes a partner preview on
    // top of this route, and pop() removes the TOPMOST route — so a
    // coupleId arriving while the user sat on that preview would pop the
    // preview and strand the now-paired user on a stale share screen
    // (adversarial-review finding, Session 010). popUntil(isFirst) lands on
    // the gate, which has already re-routed (paired home / auth shell).
    void popToGate() {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    ref.listen(profileStreamProvider(uid), (previous, next) {
      // A settled profile with a coupleId is the pairing terminal; fires on
      // the change only.
      if (!next.isLoading && next.value?.coupleId != null) popToGate();
    });
    // The share screen's sign-out is reachable on this pushed route. The
    // gate-mounted share screen used to be swapped out by the auth shell
    // automatically; a pushed route must pop itself to uncover it, or the
    // signed-out user is stranded on a dead share screen.
    ref.listen(authControllerProvider, (previous, next) {
      if (next is! AuthSignedIn) popToGate();
    });
    return const InviteShareScreen();
  }
}
