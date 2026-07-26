import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design_system/color_tokens.dart';
import '../design_system/elevation_tokens.dart';

/// The seed vessel — the brand's hero object (creative-assets §6.1): a low,
/// wide glass-ceramic bowl in an Anatolian çini silhouette, drawn in the
/// Nightbloom flat layers — Night Raised body, Veil rim hairline, Clay foot —
/// visibly holding one Pomegranate seed per mutual day. It replaces the
/// Material heart on the paired home's streak strip, and later renders at
/// full size on the Us screen.
///
/// States (product spec: empty · first-seed · 7-day · 30-day · mercy-day):
/// - [seedCount] 0: the empty bowl — the caller pairs it with the canonical
///   empty line ("Your first seed arrives the first day you both answer.").
/// - 1–[maxIndividualSeeds]: seeds drawn individually, clustered naturally
///   (deterministic hand-placed offsets, not a grid).
/// - above [maxIndividualSeeds]: a rising fill level (the count itself renders
///   as text in the strip, tabular figures — outside this glyph).
/// - [streakSafe]: a Sage glint on the topmost seed (after today's reveal).
/// - [mercyDayUsed]: a small Sage leaf laid over the seeds — forgiveness as
///   grace, never "streak freeze" mechanics.
///
/// The bowl casts the plum Level-1 card shadow ([ElevationTokens.level1] —
/// never black). The glyph is decorative ([ExcludeSemantics]): the strip's
/// text carries the meaning for screen readers. Drawn symmetric — certified
/// RTL-neutral (creative-assets §"RTL": non-directional assets are drawn
/// symmetric-safe), so no mirrored variant exists.
class SeedVessel extends StatelessWidget {
  const SeedVessel({
    super.key,
    required this.seedCount,
    this.streakSafe = false,
    this.mercyDayUsed = false,
    this.width = 28,
  });

  /// Mutual days = seeds. Server truth ([CoupleStreak.count]'s value) — the
  /// vessel never anticipates a count the trigger has not written.
  final int seedCount;

  /// Topmost seed carries the Sage glint (after today's reveal).
  final bool streakSafe;

  /// The grace token was spent this week: the Sage leaf rests on the seeds.
  final bool mercyDayUsed;

  /// Rendered width; height follows the low-wide silhouette (0.78 ratio).
  final double width;

  /// Seeds render individually up to here; beyond, the rising fill level
  /// (creative-assets §6.1).
  static const int maxIndividualSeeds = 14;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, width * 0.78),
        painter: _SeedVesselPainter(
          seedCount: seedCount,
          streakSafe: streakSafe,
          mercyDayUsed: mercyDayUsed,
        ),
      ),
    );
  }
}

class _SeedVesselPainter extends CustomPainter {
  const _SeedVesselPainter({
    required this.seedCount,
    required this.streakSafe,
    required this.mercyDayUsed,
  });

  final int seedCount;
  final bool streakSafe;
  final bool mercyDayUsed;

  /// Hand-placed cluster positions (fractions of the canvas), bottom-up so
  /// seeds pile the way pomegranate seeds settle — "clustered naturally, not
  /// a grid" (ui-ux §6.3). Deterministic: goldens never flake.
  static const List<Offset> _cluster = [
    Offset(0.50, 0.72),
    Offset(0.38, 0.70),
    Offset(0.62, 0.71),
    Offset(0.30, 0.64),
    Offset(0.56, 0.65),
    Offset(0.70, 0.64),
    Offset(0.44, 0.62),
    Offset(0.34, 0.56),
    Offset(0.60, 0.57),
    Offset(0.48, 0.54),
    Offset(0.70, 0.55),
    Offset(0.40, 0.48),
    Offset(0.55, 0.47),
    Offset(0.64, 0.46),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rimRect = Rect.fromCenter(
      center: Offset(0.5 * w, 0.36 * h),
      width: 0.88 * w,
      height: 0.23 * h,
    );

    // The bowl body: from the rim's start edge, a low wide belly to the
    // bottom, back up to the rim's end edge, closed along the rim's lower
    // arc. Symmetric — RTL-neutral by construction.
    final body = Path()
      ..moveTo(0.06 * w, 0.36 * h)
      ..cubicTo(0.07 * w, 0.60 * h, 0.24 * w, 0.80 * h, 0.5 * w, 0.80 * h)
      ..cubicTo(0.76 * w, 0.80 * h, 0.93 * w, 0.60 * h, 0.94 * w, 0.36 * h)
      ..arcTo(rimRect, 0, math.pi, false)
      ..close();

    // Clay foot, tucked under the belly.
    final foot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0.5 * w, 0.86 * h),
        width: 0.30 * w,
        height: 0.09 * h,
      ),
      Radius.circular(0.03 * h),
    );
    canvas.drawRRect(foot, Paint()..color = ColorTokens.clay);

    // The plum Level-1 shadow (ui-ux §9.3 — never black): the token's exact
    // color/offset/blur, drawn by hand since this glyph owns its decoration.
    final shadow = ElevationTokens.level1.first;
    canvas.save();
    canvas.translate(shadow.offset.dx, shadow.offset.dy);
    canvas.drawPath(body, shadow.toPaint());
    canvas.restore();

    // Night Raised body.
    canvas.drawPath(body, Paint()..color = ColorTokens.nightRaised);

    // Seeds (clipped to the bowl so the fill/cluster never bleeds).
    canvas.save();
    canvas.clipPath(body);
    if (seedCount > SeedVessel.maxIndividualSeeds) {
      _paintFill(canvas, w, h);
    } else if (seedCount > 0) {
      _paintCluster(canvas, w, h);
    }
    canvas.restore();

    // Veil rim hairline over everything — the glass edge.
    canvas.drawOval(
      rimRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, 0.045 * w)
        ..color = ColorTokens.veil,
    );

    if (mercyDayUsed) _paintMercyLeaf(canvas, w, h);
  }

  void _paintCluster(Canvas canvas, double w, double h) {
    final r = 0.09 * w;
    final n = seedCount.clamp(0, SeedVessel.maxIndividualSeeds);
    for (var i = 0; i < n; i++) {
      final c = Offset(_cluster[i].dx * w, _cluster[i].dy * h);
      _paintSeed(canvas, c, r);
      final topmost = i == n - 1;
      if (topmost && streakSafe) _paintGlint(canvas, c, r);
    }
  }

  void _paintFill(Canvas canvas, double w, double h) {
    // Rising fill: 15 seeds sit at ~1/3, 100 nearly brim the bowl.
    final fraction = 0.35 + 0.55 * (((seedCount - 15) / 85).clamp(0.0, 1.0));
    final fillTop = ui.lerpDouble(0.78 * h, 0.42 * h, fraction)!;
    final rect = Rect.fromLTRB(0, fillTop, w, 0.82 * h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0.5 * w, fillTop),
          Offset(0.5 * w, 0.82 * h),
          const [ColorTokens.pomegranate, ColorTokens.pomegranateDeep],
        ),
    );
    if (streakSafe) {
      _paintGlint(canvas, Offset(0.5 * w, fillTop + 0.06 * h), 0.10 * w);
    }
  }

  /// One seed: the sanctioned pomegranate → pomegranate-deep gradient pair
  /// (ui-ux §9.4 — seed shading is one of its two licensed uses).
  void _paintSeed(Canvas canvas, Offset c, double r) {
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
  }

  /// The streak-safe glint: one Sage highlight on the topmost seed
  /// (creative-assets §6.1 — a state, never looping ambience).
  void _paintGlint(Canvas canvas, Offset c, double r) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.72),
      -2.6,
      1.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1, r * 0.35)
        ..color = ColorTokens.sage,
    );
  }

  /// The mercy leaf: a small Sage leaf laid over the seeds — the grace token
  /// made visible as forgiveness (creative-assets §6.4).
  void _paintMercyLeaf(Canvas canvas, double w, double h) {
    canvas.save();
    canvas.translate(0.5 * w, 0.38 * h);
    canvas.rotate(-0.5);
    final leaf = Path()
      ..moveTo(-0.10 * w, 0)
      ..quadraticBezierTo(0, -0.09 * w, 0.10 * w, 0)
      ..quadraticBezierTo(0, 0.09 * w, -0.10 * w, 0)
      ..close();
    canvas.drawPath(leaf, Paint()..color = ColorTokens.sage);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SeedVesselPainter oldDelegate) =>
      oldDelegate.seedCount != seedCount ||
      oldDelegate.streakSafe != streakSafe ||
      oldDelegate.mercyDayUsed != mercyDayUsed;
}
