import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/motion_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/storage/local_flag_store.dart';
import '../../../core/widgets/soft_unfold_reveal.dart';
import 'state/ritual_preview_seen.dart';

/// Testing handle on the preview's soft-unfold (the per-surface
/// [SoftUnfoldReveal.opacityKey] convention).
@visibleForTesting
const ritualPreviewUnfoldKey = ValueKey<String>('ritual-preview-unfold');

/// The pre-sign-in ritual preview (redesign M-5, ui-ux §5.1 step 1 / §6.1):
/// three swipeable cards — the ritual, the seal, the privacy — selling the
/// product in 15 seconds before asking for anything. The store description's
/// pitch, finally used inside the app; the only marketing surface it has.
///
/// Skippable always: a "Sign in" text button rides every page (the skip
/// affordance IS sign-in). Card 3's CTA is "Get started"; cards 1–2 advance
/// with Continue. Any exit marks the device-local [ritualPreviewSeenKey] and
/// bumps [ritualPreviewSeenProvider], so `SignInScreen` swaps to the auth
/// shell reactively and the preview is never shown again (first completion
/// only — ui-ux §6.1). Invitees who arrive on a pending invite code never
/// see this screen at all: the partner preview outranks it (§5.3 — they came
/// for a person, not a pitch).
///
/// The Nightbloom illustrations (creative-assets §4) are pending brand
/// assets; a Clay stand-in glyph holds each card's top region so the
/// composition (art → headline → body → dots → actions) is already the
/// shipped structure. Card entries use the base soft unfold; the page
/// advance honours reduce-motion by jumping instead of sliding. All motion
/// is horizontal-by-PageView (direction-mirrored by the framework) or
/// vertical — RTL-safe by construction.
class RitualPreviewScreen extends ConsumerStatefulWidget {
  const RitualPreviewScreen({super.key});

  @override
  ConsumerState<RitualPreviewScreen> createState() =>
      _RitualPreviewScreenState();
}

class _RitualPreviewScreenState extends ConsumerState<RitualPreviewScreen> {
  final PageController _controller = PageController();

  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Durable flag first, reactive bump second (the coupleEndedSeen ordering):
  /// when `SignInScreen` re-evaluates, the flag is already set.
  Future<void> _complete() async {
    await ref.read(localFlagStoreProvider).set(ritualPreviewSeenKey);
    ref.read(ritualPreviewSeenProvider.notifier).markSeen();
  }

  void _advance() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
      return;
    }
    unawaited(
      _controller.nextPage(
        duration: MotionTokens.revealUnfold,
        curve: MotionTokens.enter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cards = [
      (
        icon: Icons.forum_outlined,
        headline: l10n.ritualPreviewHeadline1,
        body: l10n.ritualPreviewBody1,
      ),
      (
        icon: Icons.mail_outline,
        headline: l10n.ritualPreviewHeadline2,
        body: l10n.ritualPreviewBody2,
      ),
      (
        icon: Icons.lock_outline,
        headline: l10n.ritualPreviewHeadline3,
        body: l10n.ritualPreviewBody3,
      ),
    ];
    final lastPage = _page == cards.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: cards.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.screenGutter,
                      vertical: SpacingTokens.x6,
                    ),
                    child: SoftUnfoldReveal(
                      opacityKey: ritualPreviewUnfoldKey,
                      child: Column(
                        children: [
                          // The illustration region (creative-assets §4
                          // Nightbloom compositions pending): a quiet Clay
                          // stand-in glyph holds the slot.
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: SpacingTokens.x8,
                            ),
                            child: Icon(
                              card.icon,
                              size: 64,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          Text(
                            card.headline,
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: SpacingTokens.x4),
                          Text(card.body, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _PageDots(count: cards.length, active: _page),
            const SizedBox(height: SpacingTokens.x6),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenGutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: lastPage
                        ? () => unawaited(_complete())
                        : _advance,
                    child: Text(
                      lastPage ? l10n.ritualPreviewCta : l10n.continueAction,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.x2),
                  // The skip affordance IS sign-in — present on every page,
                  // Rose (the theme's TextButton role).
                  TextButton(
                    onPressed: () => unawaited(_complete()),
                    child: Text(l10n.ritualPreviewSkip),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.x4),
          ],
        ),
      ),
    );
  }
}

/// Page dots: Veil inactive, Pomegranate active (ui-ux §6.1). Sized for a
/// clear reading, not for touch — the whole page swipes.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: SpacingTokens.x1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
