import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design_system/color_tokens.dart';
import '../design_system/spacing_tokens.dart';

/// The solo week's seven-seed position row (redesign QW-9): the solo cycle is
/// seven days long and the screen said so only in words ("Day 3 of 7"). This
/// draws the same sentence, so progression through the cycle is *seen* before
/// it is read — which is what feeds the pairing nudge.
///
/// **It shows POSITION, never achievement, and the distinction is load-bearing.**
/// The solo screen knows which day of the cycle you are on — it is anchored on
/// the rules-enforced `users/{uid}.createdAt` — and it does NOT know which days
/// you actually answered. Filling a seed per elapsed day would therefore claim
/// something unmeasured: three seeds for a user who wrote once. So the row reads
/// as a calendar, not a scoreboard:
///
/// - days behind you — a Veil dot, spent and quiet;
/// - today — one Pomegranate seed, in the vessel's own gradient
///   ([SeedVessel] shades every seed the same way, ui-ux §9.4);
/// - days ahead — a Veil hairline ring, empty and waiting.
///
/// The one filled seed is today's, and that is true by construction.
///
/// Decorative ([ExcludeSemantics]) — the "Day N of 7" caption beside it already
/// carries the meaning for a screen reader, and two readings of the same fact is
/// noise. Symmetric and drawn start-to-end in the ambient [Directionality] via a
/// [Row], so RTL mirrors it for free; the seed shape itself is a circle, so it
/// has no handedness to mirror (`tool/rtl_lint.dart`'s logical-direction rule).
class SeedWeekRow extends StatelessWidget {
  const SeedWeekRow({super.key, required this.day, this.seedSize = 10});

  /// The 1-based day of the solo cycle. Values outside 1..[cycleLength] are
  /// clamped, so a clock skew or a day-8 cold open cannot paint an empty row.
  final int day;

  /// Diameter of one seed, in dp.
  final double seedSize;

  /// The solo cycle's length (M2.4 — seven questions, then [soloCycleComplete]).
  static const int cycleLength = 7;

  @override
  Widget build(BuildContext context) {
    final today = day.clamp(1, cycleLength);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var slot = 1; slot <= cycleLength; slot++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.x1 / 2,
              ),
              child: CustomPaint(
                size: Size.square(seedSize),
                painter: _SeedSlotPainter(
                  state: slot < today
                      ? _SlotState.behind
                      : slot == today
                      ? _SlotState.today
                      : _SlotState.ahead,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _SlotState { behind, today, ahead }

class _SeedSlotPainter extends CustomPainter {
  const _SeedSlotPainter({required this.state});

  final _SlotState state;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    switch (state) {
      case _SlotState.today:
        // The vessel's seed shading, verbatim (ui-ux §9.4 licenses the
        // pomegranate → pomegranate-deep pair for seeds).
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = ui.Gradient.linear(
              c.translate(-r * 0.6, -r * 0.8),
              c.translate(r * 0.6, r),
              const [ColorTokens.pomegranate, ColorTokens.pomegranateDeep],
            ),
        );
      case _SlotState.behind:
        canvas.drawCircle(c, r, Paint()..color = ColorTokens.veil);
      case _SlotState.ahead:
        canvas.drawCircle(
          c,
          r - 0.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = ColorTokens.veil,
        );
    }
  }

  @override
  bool shouldRepaint(_SeedSlotPainter oldDelegate) =>
      oldDelegate.state != state;
}
