import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import 'paywall_screen.dart';
import 'premium_gate.dart';

/// The first gated surface (ADR-014 Decision 4): the couple's question packs,
/// wrapped in [PremiumGate]. Unlocked couples see the current bank presented
/// honestly (starter collection, more on the way — W9 authors real packs, no
/// `packConfig` writes this session); free couples see the lock + the premium
/// pitch. The gate lives here, in ONE place — the paired-home tile never
/// re-decides.
class PackSelectionScreen extends ConsumerWidget {
  const PackSelectionScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth-loss self-pop (the `_PushedInviteShare` idiom): a remote sign-out
    // would otherwise strand the user on this pushed sheet over the auth shell.
    ref.listen(authControllerProvider, (previous, next) {
      if (next is! AuthSignedIn) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

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
                Text(
                  l10n.packSelectionTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x6),
                PremiumGate(
                  coupleId: coupleId,
                  unlocked: const _UnlockedView(),
                  locked: _GatedView(coupleId: coupleId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium: the current bank shown honestly. Static — no data reads, no
/// `packConfig` writes (a selection write path is W9's decision, ADR-011).
class _UnlockedView extends StatelessWidget {
  const _UnlockedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(SpacingTokens.cardPadding),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: RadiusTokens.cardRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.packSelectionCurrentTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: SpacingTokens.x2),
              Text(
                l10n.packSelectionCurrentBody,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.x3),
        Text(
          l10n.packSelectionComing,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Free: the lock presentation, the premium pitch, and the CTA to the paywall.
class _GatedView extends StatelessWidget {
  const _GatedView({required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_outline, size: 40, color: theme.colorScheme.secondary),
        const SizedBox(height: SpacingTokens.x3),
        Text(
          l10n.packSelectionGatedTitle,
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SpacingTokens.x3),
        Text(
          l10n.packSelectionGatedBody,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SpacingTokens.x6),
        FilledButton(
          onPressed: () => showPaywall(context, coupleId: coupleId),
          child: Text(l10n.packSelectionGatedCta),
        ),
      ],
    );
  }
}
