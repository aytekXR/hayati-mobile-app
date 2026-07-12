import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/storage/local_flag_store.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../entitlements/presentation/paywall_screen.dart';
import '../../entitlements/presentation/premium_gate.dart';
import '../../profile/domain/relationship_profile.dart';
import '../../profile/presentation/state/profile_providers.dart';
import '../domain/coach_disclaimer.dart';
import '../domain/coach_exception.dart';
import '../domain/coach_persona.dart';
import '../domain/coach_register.dart';
import '../domain/coach_transcript_entry.dart';
import '../domain/coach_window.dart';
import 'state/coach_send_controller.dart';
import 'state/coach_transcript.dart';

/// Pushes the coach chat over the current route — the single entry point the
/// paired-home coach tile uses (ADR-017 Decision 1, the `showPaywall` mold).
/// Couple-scoped by signature: a [coupleId] exists only post-join, and the tile
/// is mounted inside the gate's unlocked subtree, so a free user never reaches
/// this.
Future<void> showCoach(
  BuildContext context, {
  required String uid,
  required String coupleId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CoachScreen(uid: uid, coupleId: coupleId),
    ),
  );
}

/// The couple-facing coach chat (ADR-017): one screen, a persona switcher, and
/// one ephemeral transcript per persona. Pushed over the paired home; mounts the
/// chat on the [PremiumGate] seam (ADR-014) so a mid-session downgrade collapses
/// to the honest gated view. The disclaimer gate (Decision 4) and the layered
/// profile settle (Decision 1) both sit inside the unlocked subtree.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key, required this.uid, required this.coupleId});

  final String uid;
  final String coupleId;

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  /// The selected persona — swapping it swaps the visible transcript AND the
  /// send-controller family key (per-persona conversations never mix windows,
  /// Decision 1). The composer draft is deliberately shared across personas
  /// (one controller).
  CoachPersonaId _persona = CoachPersonaId.coach;

  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auth-loss self-pop (the `_PushedInviteShare` idiom): a remote sign-out
    // would otherwise strand the user on this pushed route over the auth shell.
    ref.listen(authControllerProvider, (previous, next) {
      if (next is! AuthSignedIn) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final l10n = AppLocalizations.of(context);
    // The active persona's transcript drives the app-bar reset affordance: the
    // "new conversation" action is offered only once a conversation exists.
    final transcript = ref.watch(
      coachTranscriptProvider(widget.uid, widget.coupleId, _persona),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.coachTitle),
        actions: [
          if (transcript.entries.isNotEmpty)
            IconButton(
              tooltip: l10n.coachNewConversation,
              icon: const Icon(Icons.refresh),
              // Resets ONLY the active persona's transcript (family isolation).
              onPressed: () => ref
                  .read(
                    coachTranscriptProvider(
                      widget.uid,
                      widget.coupleId,
                      _persona,
                    ).notifier,
                  )
                  .reset(),
            ),
        ],
      ),
      body: PremiumGate(
        coupleId: widget.coupleId,
        unlocked: _CoachChatBody(
          uid: widget.uid,
          coupleId: widget.coupleId,
          persona: _persona,
          controller: _controller,
          onPersonaSelected: (persona) => setState(() => _persona = persona),
          // The ack callback runs after a genuine platform-channel await (the
          // shared-preferences write); this screen's auth-loss listener can
          // self-pop and dispose this State during that gap, so the rebuild is
          // gated on `mounted` (S019 review find).
          onDisclaimerAck: () {
            if (mounted) setState(() {});
          },
        ),
        locked: _CoachGatedView(coupleId: widget.coupleId),
      ),
    );
  }
}

/// The chat body inside the gate: the disclaimer gate (Decision 4) then the
/// layered profile settle (Decision 1). A [ConsumerWidget] so its profile
/// subscription is scoped to when the couple is actually premium (the gate only
/// mounts this subtree then).
class _CoachChatBody extends ConsumerWidget {
  const _CoachChatBody({
    required this.uid,
    required this.coupleId,
    required this.persona,
    required this.controller,
    required this.onPersonaSelected,
    required this.onDisclaimerAck,
  });

  final String uid;
  final String coupleId;
  final CoachPersonaId persona;
  final TextEditingController controller;
  final ValueChanged<CoachPersonaId> onPersonaSelected;
  final VoidCallback onDisclaimerAck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Disclaimer gate FIRST (Decision 4): until acknowledged per device+uid,
    // NOTHING else renders — no transcript, no composer, no profile read.
    final flags = ref.watch(localFlagStoreProvider);
    if (!flags.isSet(coachDisclaimerAckKey(uid))) {
      return _CoachDisclaimerView(
        onAcknowledge: () async {
          await ref.read(localFlagStoreProvider).set(coachDisclaimerAckKey(uid));
          onDisclaimerAck();
        },
      );
    }

    // Layered profile settle (Decision 1): the composer is only constructible
    // from a settled non-null profile, so every send has a derivable
    // language/register by construction.
    final profile = ref.watch(profileStreamProvider(uid));
    if (profile.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final value = profile.value;
    if (profile.hasError || value == null) {
      return _CoachProfileErrorView(
        onRetry: () => ref.invalidate(profileStreamProvider(uid)),
      );
    }

    return _CoachChat(
      uid: uid,
      coupleId: coupleId,
      persona: persona,
      profile: value,
      controller: controller,
      onPersonaSelected: onPersonaSelected,
    );
  }
}

/// The settled chat: persona chips, the per-persona transcript, the daily quota
/// caption, and either the composer or the help-latched paused panel.
class _CoachChat extends ConsumerStatefulWidget {
  const _CoachChat({
    required this.uid,
    required this.coupleId,
    required this.persona,
    required this.profile,
    required this.controller,
    required this.onPersonaSelected,
  });

  final String uid;
  final String coupleId;
  final CoachPersonaId persona;
  final RelationshipProfile profile;
  final TextEditingController controller;
  final ValueChanged<CoachPersonaId> onPersonaSelected;

  @override
  ConsumerState<_CoachChat> createState() => _CoachChatState();
}

class _CoachChatState extends ConsumerState<_CoachChat> {
  void _send() {
    final entry = widget.controller.text.trim();
    if (entry.isEmpty || entry.length > kCoachMessageMaxChars) return;
    unawaited(
      ref
          .read(
            coachSendControllerProvider(
              widget.uid,
              widget.coupleId,
              widget.persona,
            ).notifier,
          )
          .send(
            text: entry,
            language: widget.profile.contentLanguage,
            register: coachRegisterFor(
              widget.profile.contentLanguage,
              widget.profile.register,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transcript = ref.watch(
      coachTranscriptProvider(widget.uid, widget.coupleId, widget.persona),
    );
    final sendState = ref.watch(
      coachSendControllerProvider(widget.uid, widget.coupleId, widget.persona),
    );

    // Side-effects on send transitions: clear the draft when a send settles
    // (server-ack cleared the input), and push the paywall on a not-premium
    // failure — the gated state will show behind once the mirror flips.
    ref.listen(
      coachSendControllerProvider(widget.uid, widget.coupleId, widget.persona),
      (previous, next) {
        if (previous is CoachSendSending && next is CoachSendIdle) {
          widget.controller.clear();
        }
        if (next is CoachSendFailure &&
            next.failure is CoachNotPremiumException) {
          showPaywall(context, coupleId: widget.coupleId);
        }
      },
    );

    final sending = sendState is CoachSendSending;
    final entries = transcript.entries;
    final remaining = transcript.lastRemaining;
    final failure = sendState is CoachSendFailure ? sendState.failure : null;
    final failureCopy = failure == null ? null : _coachFailureCopy(l10n, failure);

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoachPersonaChips(
            selected: widget.persona,
            onSelected: widget.onPersonaSelected,
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.screenGutter,
                      ),
                      child: Text(
                        l10n.coachEmptyState,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.screenGutter,
                      vertical: SpacingTokens.x3,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      // reverse:true renders bottom-up; map to oldest-first.
                      final entry = entries[entries.length - 1 - index];
                      return _CoachEntry(entry: entry, persona: widget.persona);
                    },
                  ),
          ),
          // Quota caption (Decision 6): daily-only, response-hint only, absent
          // before the first hint and suppressed while latched. Never a gate.
          if (remaining != null && !transcript.helpSticky)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenGutter,
                vertical: SpacingTokens.x2,
              ),
              child: Text(
                remaining.daily == 0
                    ? l10n.coachQuotaExhausted
                    : l10n.coachQuotaRemaining(remaining.daily),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          if (transcript.helpSticky)
            CoachPausedPanel(
              onNewConversation: () => ref
                  .read(
                    coachTranscriptProvider(
                      widget.uid,
                      widget.coupleId,
                      widget.persona,
                    ).notifier,
                  )
                  .reset(),
            )
          else
            _CoachComposer(
              controller: widget.controller,
              sending: sending,
              failureCopy: failureCopy,
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

/// The three persona choice chips (Decision 1). Selecting one swaps the visible
/// transcript and the send-controller key; enabled during a send (a mid-send
/// switch still lands the reply in the originating persona, Decision 8).
class _CoachPersonaChips extends StatelessWidget {
  const _CoachPersonaChips({required this.selected, required this.onSelected});

  final CoachPersonaId selected;
  final ValueChanged<CoachPersonaId> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.screenGutter,
        SpacingTokens.x3,
        SpacingTokens.screenGutter,
        0,
      ),
      child: Wrap(
        spacing: SpacingTokens.x2,
        children: [
          for (final persona in CoachPersonaId.values)
            ChoiceChip(
              label: Text(_coachPersonaLabel(l10n, persona)),
              selected: persona == selected,
              onSelected: (_) => onSelected(persona),
            ),
        ],
      ),
    );
  }
}

/// Dispatches one transcript entry to its structurally distinct widget: user
/// bubble, persona bubble, or the help card (Decision 8 — the TYPE distinction
/// is pinned by tests so a refactor cannot re-bubble the help path).
class _CoachEntry extends StatelessWidget {
  const _CoachEntry({required this.entry, required this.persona});

  final CoachTranscriptEntry entry;
  final CoachPersonaId persona;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      CoachUserTurn(:final text) => CoachUserBubble(text: text),
      CoachPersonaTurn(:final text) => CoachPersonaBubble(
        text: text,
        persona: persona,
      ),
      CoachHelpTurn(:final text) => CoachHelpCard(text: text),
    };
  }
}

/// A user turn: an end-aligned bubble in the raised surface tone.
class CoachUserBubble extends StatelessWidget {
  const CoachUserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.x3),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.all(SpacingTokens.x3),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: RadiusTokens.cardRadius,
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A persona reply turn: a start-aligned bubble with a small persona-label chip
/// above it (visual attribution, Decision 8).
class CoachPersonaBubble extends StatelessWidget {
  const CoachPersonaBubble({super.key, required this.text, required this.persona});

  final String text;
  final CoachPersonaId persona;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: SpacingTokens.x1,
              bottom: SpacingTokens.x1,
            ),
            child: Text(
              _coachPersonaLabel(l10n, persona),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.all(SpacingTokens.x3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: RadiusTokens.cardRadius,
              ),
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

/// A safety help turn (`kind:'help'`): a full-width, alert-tinted card with the
/// warm header and the server help text verbatim — NEVER a persona bubble
/// (Decision 8). The TYPE distinction is pinned by tests.
class CoachHelpCard extends StatelessWidget {
  const CoachHelpCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.x3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SpacingTokens.cardPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: RadiusTokens.cardRadius,
          border: Border.all(color: theme.colorScheme.error),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: SpacingTokens.x2),
                Expanded(
                  child: Text(
                    l10n.coachHelpTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.x2),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// The composer: the message field plus the send button. Replaced entirely by
/// [CoachPausedPanel] while a conversation is help-latched (Decision 2). The
/// send button re-evaluates on every keystroke via the controller listenable.
class _CoachComposer extends StatelessWidget {
  const _CoachComposer({
    required this.controller,
    required this.sending,
    required this.failureCopy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final String? failureCopy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // The app theme's FilledButton style sets minimumSize Size.fromHeight(48) =
    // Size(∞, 48) so primary CTAs are full-width Column children. Inside a Row
    // that infinite MIN width explodes layout, so the composer's inline buttons
    // override the min width to 0 while keeping the 48dp touch-target height
    // (brandkit §8).
    final inlineButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.screenGutter,
        SpacingTokens.x2,
        SpacingTokens.screenGutter,
        SpacingTokens.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failureCopy != null) ...[
            Text(
              failureCopy!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.x2),
          ],
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final entry = controller.text.trim();
              final tooLong = entry.length > kCoachMessageMaxChars;
              if (!tooLong) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.x2),
                child: Text(
                  l10n.coachInputTooLong,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  // UX convenience only — it counts graphemes, so the send gate
                  // below re-checks in UTF-16 code units (Decision 2 rule 5).
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(kCoachMessageMaxChars),
                  ],
                  decoration: InputDecoration(hintText: l10n.coachInputHint),
                ),
              ),
              const SizedBox(width: SpacingTokens.x2),
              if (sending)
                FilledButton(
                  onPressed: null,
                  style: inlineButtonStyle,
                  child: const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final entry = controller.text.trim();
                    final canSend =
                        entry.isNotEmpty &&
                        entry.length <= kCoachMessageMaxChars;
                    return FilledButton(
                      onPressed: canSend ? onSend : null,
                      style: inlineButtonStyle,
                      child: Text(l10n.coachSend),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The help-latched paused panel (Decision 2): replaces the composer so no
/// further sends can issue from this conversation. "Start a new conversation"
/// is the only forward action.
class CoachPausedPanel extends StatelessWidget {
  const CoachPausedPanel({super.key, required this.onNewConversation});

  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.screenGutter,
        SpacingTokens.x3,
        SpacingTokens.screenGutter,
        SpacingTokens.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.coachPausedBody,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.x3),
          FilledButton(
            onPressed: onNewConversation,
            child: Text(l10n.coachNewConversation),
          ),
        ],
      ),
    );
  }
}

/// The first-open disclaimer gate (Decision 4): the not-therapy note with a
/// single acknowledge CTA. Until acknowledged nothing else renders.
class _CoachDisclaimerView extends StatelessWidget {
  const _CoachDisclaimerView({required this.onAcknowledge});

  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
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
                l10n.coachDisclaimerTitle,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.x3),
              Text(
                l10n.coachDisclaimerBody,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.x6),
              FilledButton(
                onPressed: onAcknowledge,
                child: Text(l10n.coachDisclaimerCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The layered profile-settle failure (Decision 1): an honest error with a
/// retry that re-subscribes the profile stream. Reuses the shared error keys.
class _CoachProfileErrorView extends StatelessWidget {
  const _CoachProfileErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenGutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.errorGeneric,
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
    );
  }
}

/// The mid-session downgrade gated view (ADR-017 Decision 1, the pack-selection
/// `_GatedView` mold): lock + honest couple-scoped copy + a paywall CTA. Defense
/// in depth — a free user never reaches the screen (the tile renders nothing).
class _CoachGatedView extends StatelessWidget {
  const _CoachGatedView({required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
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
              Icon(
                Icons.lock_outline,
                size: 40,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(height: SpacingTokens.x3),
              Text(
                l10n.coachGatedTitle,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.x3),
              Text(
                l10n.coachGatedBody,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.x6),
              FilledButton(
                onPressed: () => showPaywall(context, coupleId: coupleId),
                child: Text(l10n.coachGatedCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Localized persona label for chips and reply attribution.
String _coachPersonaLabel(AppLocalizations l10n, CoachPersonaId persona) =>
    switch (persona) {
      CoachPersonaId.coach => l10n.coachPersonaCoach,
      CoachPersonaId.dateGenie => l10n.coachPersonaDateGenie,
      CoachPersonaId.giftGenie => l10n.coachPersonaGiftGenie,
    };

/// Maps a send failure to its inline copy (Decision 5 table). Returns null for
/// [CoachNotPremiumException] — that failure pushes the paywall instead of
/// rendering an inline line.
String? _coachFailureCopy(AppLocalizations l10n, CoachException failure) =>
    switch (failure) {
      CoachUnavailableException() => l10n.coachErrorUnavailable,
      CoachRateLimitedException() => l10n.coachErrorRateLimited,
      CoachDailyCapException() => l10n.coachErrorCapDaily,
      CoachMonthlyCapException() => l10n.coachErrorCapMonthly,
      CoachLimitReachedException() => l10n.coachErrorLimit,
      CoachNotMemberException() => l10n.coachErrorGeneric,
      CoachUnknownException() => l10n.coachErrorGeneric,
      CoachNotPremiumException() => null,
    };
