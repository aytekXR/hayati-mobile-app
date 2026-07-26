import 'package:flutter/material.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/widgets/reveal_choreography.dart';
import '../../../core/widgets/seed_vessel.dart';
import '../domain/couple.dart';

/// The streak strip (redesign ui-ux §6.3, layout slot 2): the miniature seed
/// vessel + the seeds/days line, always present on the paired question view —
/// it replaces the M3.4 revealed-only Material-heart row. Fed by the shipped
/// server streak ([CoupleStreak], ADR-012); the client never anticipates a
/// count the reveal trigger has not written, so on a live reveal the seed
/// DROPS first and the count catches up when the server write streams in.
///
/// States:
/// - count 0: the empty vessel + the canonical honest line ("Your first seed
///   arrives the first day you both answer.") — a zero never masquerades as a
///   streak (the M3.4 honesty rule, kept in redesigned clothes).
/// - count > 0: the vessel holding one seed per mutual day + "{count} seeds ·
///   {count} days together" in tabular figures.
/// - grace token spent this ISO week ([CoupleStreak.graceTokens] == 0): the
///   Sage leaf on the vessel + the compact mercy caption in Sage.
///
/// [seedDrop] (the choreography's beat 3) wraps the vessel itself in a
/// [SeedDropOverlay], so the falling seed lands exactly on the vessel
/// wherever the strip's layout puts it — logical start/end only, so the
/// composition mirrors under RTL with no variant.
class StreakStrip extends StatelessWidget {
  const StreakStrip({
    super.key,
    required this.streak,
    this.streakSafe = false,
    this.seedDrop,
  });

  /// Live server truth off the couple doc (ADR-012).
  final CoupleStreak streak;

  /// Today's reveal has landed: the topmost seed carries the Sage glint.
  final bool streakSafe;

  /// Beat-3 progress from [RevealChoreography] — null outside the reveal (and
  /// at count 0, where there is no seed to celebrate yet: the strip updates
  /// live when the trigger writes the first streak).
  final Animation<double>? seedDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final mercyUsed = streak.graceTokens < 1;

    Widget vessel = SeedVessel(
      seedCount: streak.count,
      streakSafe: streakSafe && streak.count > 0,
      mercyDayUsed: mercyUsed,
    );
    final drop = seedDrop;
    if (drop != null) {
      vessel = SeedDropOverlay(progress: drop, child: vessel);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        vessel,
        const SizedBox(width: SpacingTokens.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (streak.count > 0)
                Text(
                  l10n.streakSeeds(streak.count),
                  // Tabular figures (ui-ux §9.2): scaling/count changes never
                  // jitter the layout.
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                // The canonical vessel-empty line — honest: a seed needs both
                // answers (product-copy 'Empty states').
                Text(l10n.streakVesselEmpty, style: theme.textTheme.bodySmall),
              if (mercyUsed) ...[
                const SizedBox(height: SpacingTokens.x1),
                // The mercy indicator: Sage — success/grace, never Alert
                // (forgiveness framing, product-copy 'mercy indicator').
                Row(
                  children: [
                    const Icon(
                      Icons.eco_outlined,
                      size: 14,
                      color: ColorTokens.sage,
                    ),
                    const SizedBox(width: SpacingTokens.x1),
                    Flexible(
                      child: Text(
                        l10n.streakMercyUsed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ColorTokens.sage,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
