import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/color_tokens.dart';

/// A quiet Seljuk-lattice fragment — one eight-point star drawn as two
/// overlapping rotated squares in Clay line-work (ui-ux §9.4: "Clay …
/// lattice line-work"; 1.75 stroke, the icon-system breath) at watermark
/// opacity (§6.3 question card: "subtle 4% lattice watermark bottom-end
/// corner"; ceiling 8% per the illustration rules).
///
/// The star is point-symmetric, so the fragment is direction-neutral; its
/// PLACEMENT is the directional part and belongs to the caller
/// (PositionedDirectional bottom-end — mirrored under RTL by construction).
/// Decorative: excluded from semantics (ui-ux §8 — "decorative illustration
/// and lattice texture are excluded from the semantics tree").
class LatticeWatermark extends StatelessWidget {
  const LatticeWatermark({super.key, this.size = 72, this.opacity = 0.04});

  final double size;

  /// 4% default; never above the 8% illustration ceiling.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LatticePainter(opacity: opacity),
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      // The icon-system stroke (ui-ux §9.4: 1.75, rounded joins).
      ..strokeWidth = 1.75
      ..strokeJoin = StrokeJoin.round
      ..color = ColorTokens.clay.withValues(alpha: opacity);

    final c = Offset(size.width / 2, size.height / 2);
    final half = size.width * 0.36;

    // Two concentric squares, one rotated 45° — the classic eight-point star.
    for (final rotation in const [0.0, math.pi / 4]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
        paint,
      );
      canvas.restore();
    }

    // The inner octagonal echo the two squares imply — one more quiet line.
    canvas.drawCircle(c, half * 0.62, paint);
  }

  @override
  bool shouldRepaint(_LatticePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
