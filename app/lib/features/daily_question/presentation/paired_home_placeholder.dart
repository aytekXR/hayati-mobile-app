import 'package:flutter/material.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';

/// The screen a paired user lands on once their `users/{uid}` doc carries a
/// `coupleId` (`OnboardingGate` routes here ahead of the invite/preview
/// screens — M2.3). Deliberately minimal: this is the SLOT the M3 daily-question
/// home replaces, not a finished surface. It exists now only so the join flow
/// has somewhere honest to land — a branded "you're paired" confirmation rather
/// than a raw placeholder — and so the gate precedence (coupleId wins) is
/// testable end to end. Brand styling comes from the theme
/// (core/design_system) plus the spacing tokens; logical-direction only.
class PairedHomePlaceholder extends StatelessWidget {
  const PairedHomePlaceholder({super.key});

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
                  l10n.pairedTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(l10n.pairedBody, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
