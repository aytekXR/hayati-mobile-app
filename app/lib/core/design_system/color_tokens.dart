import 'dart:ui';

/// Brand palette from docs/frontend-brandkit.md §2 (dark-first UI).
///
/// Usage rules from the brandkit: [gold] is for premium/celebration accents
/// only, never body UI; [alert] never appears in marketing surfaces; all text
/// pairings against [night] meet >=4.5:1 contrast.
abstract final class ColorTokens {
  static const Color night = Color(0xFF231A33);
  static const Color nightRaised = Color(0xFF2E2344);
  static const Color pomegranate = Color(0xFFC04A5A);
  static const Color pomegranateDeep = Color(0xFF8E3140);
  static const Color sand = Color(0xFFF3E7D7);
  static const Color gold = Color(0xFFD9A441);
  static const Color sage = Color(0xFF8FAE8B);
  static const Color clay = Color(0xFFB98A6E);
  static const Color alert = Color(0xFFD96C5F);
}
