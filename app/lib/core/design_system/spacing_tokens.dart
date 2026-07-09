/// Spacing tokens — the 4pt grid from hayati-tokens.json v1.0.
///
/// [x1]..[x8] are grid steps (multiples of 4); [screenGutter] and
/// [cardPadding] are the named layout tokens the brandkit calls out.
abstract final class SpacingTokens {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;

  /// Horizontal screen padding (brandkit screenGutter).
  static const double screenGutter = 20;

  /// Interior padding for cards/sheets (brandkit cardPadding).
  static const double cardPadding = 16;
}
