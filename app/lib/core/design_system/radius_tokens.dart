import 'package:flutter/material.dart';

/// Corner-radius tokens from hayati-tokens.json v1.0: card 16, sheet 24, and a
/// 'full' (stadium) radius for chips and buttons.
abstract final class RadiusTokens {
  static const double card = 16;
  static const double sheet = 24;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetRadius = BorderRadius.all(
    Radius.circular(sheet),
  );

  /// The 'full' chip radius — a stadium (pill) border for chips and buttons.
  static const StadiumBorder stadium = StadiumBorder();
}
