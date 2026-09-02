import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/color_tokens.dart';

/// The brand mark — "Two Seeds": two pomegranate seeds inclining toward each
/// other, one Pomegranate Deep and one Pomegranate carrying the Sand highlight.
///
/// **Drawn, not bundled, and the geometry is not invented.** Every number below
/// is transcribed from `brandkit/brandkit/logo/hayati-mark.svg` — the same path
/// data, the same 96×96 viewBox, the same two group transforms — so the mark in
/// the app and the mark in the brandkit cannot drift into two different shapes.
/// Painting it beats shipping `hayati-mark-512.png`: it costs no asset, no
/// `flutter_svg` dependency, stays sharp at any size, and takes its three fills
/// from [ColorTokens] (whose values are byte-identical to the SVG's `#8E3140` /
/// `#C04A5A` / `#F3E7D7`) instead of baking colour into pixels.
///
/// **It survives the rename.** The file is called `hayati-mark` and the app is
/// called `ikimiz` — lowercase, which is what ADR-035 renamed it to (ADR-032 D6
/// had recorded `İkimiz`, and this comment still said that until S095, ADR-070
/// D6); the mark carries no wordmark and no letterform, so
/// it is the one brand asset the rename did not invalidate. ADR-027's caution —
/// keep wordmark investment light while the trademark is provisional — is the
/// reason a mark, and not a name, belongs on the sign-in hero.
///
/// Symmetric about its own centre and non-directional, so RTL needs no mirrored
/// variant (creative-assets §"RTL"). Decorative by default: the caller supplies
/// the meaning in text, and [semanticLabel] exists only for a surface where the
/// mark stands alone.
class SeedMark extends StatelessWidget {
  const SeedMark({super.key, this.size = 72, this.semanticLabel});

  /// Rendered edge length, in dp. The mark is square (96×96 viewBox).
  final double size;

  /// Announced label. Null (the default) makes the mark decorative and hides it
  /// from the semantics tree.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: const _SeedMarkPainter(),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: mark)
        : Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _SeedMarkPainter extends CustomPainter {
  const _SeedMarkPainter();

  /// The SVG's authoring canvas.
  static const double _viewBox = 96;

  /// One seed, in the path's own local coordinates — verbatim from the SVG:
  /// `M0,-17 C6.5,-9.5 10,-2.5 10,3.5 A10,10 0 1 1 -10,3.5 C-10,-2.5 -6.5,-9.5 0,-17 Z`
  /// A teardrop: two cubics down each flank from the tip, closed by the
  /// large-arc sweep across the bottom.
  static Path _seedPath() => Path()
    ..moveTo(0, -17)
    ..cubicTo(6.5, -9.5, 10, -2.5, 10, 3.5)
    ..arcToPoint(
      const Offset(-10, 3.5),
      radius: const Radius.circular(10),
      largeArc: true,
      // SVG sweep-flag=1 — same handedness as Flutter's `clockwise: true`,
      // both being y-down coordinate systems.
      clockwise: true,
    )
    ..cubicTo(-10, -2.5, -6.5, -9.5, 0, -17)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    canvas.save();
    // Centre the 96×96 artwork inside whatever box the caller gave us.
    canvas.translate(
      (size.width - _viewBox * scale) / 2,
      (size.height - _viewBox * scale) / 2,
    );
    canvas.scale(scale);

    // Back seed: translate(37.5,54) rotate(-18).
    _paintSeed(canvas, 37.5, -18, ColorTokens.pomegranateDeep);
    // Front seed: translate(58.5,54) rotate(18), and it alone carries the
    // Sand highlight at 85% — the mark's single asymmetry, and what stops it
    // reading as a symmetric butterfly.
    _paintSeed(canvas, 58.5, 18, ColorTokens.pomegranate, highlight: true);

    canvas.restore();
  }

  void _paintSeed(
    Canvas canvas,
    double dx,
    double degrees,
    Color fill, {
    bool highlight = false,
  }) {
    canvas.save();
    canvas.translate(dx, 54);
    canvas.rotate(degrees * math.pi / 180);
    canvas.drawPath(_seedPath(), Paint()..color = fill);
    if (highlight) {
      canvas.drawCircle(
        const Offset(3.2, 3.2),
        2.6,
        Paint()..color = ColorTokens.sand.withValues(alpha: 0.85),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SeedMarkPainter oldDelegate) => false;
}
