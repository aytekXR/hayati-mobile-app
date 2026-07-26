import 'dart:ui';

/// Brand palette from docs/frontend-brandkit.md §2 (dark-first UI), extended
/// by the redesign token table (redesign/ui-ux-redesign.md §9.1).
///
/// Usage rules from the brandkit: [gold] is for premium/celebration accents
/// only, never body UI; [alert] never appears in marketing surfaces; all text
/// pairings against [night] meet >=4.5:1 contrast.
///
/// Values here are the dark (Night) column — the canonical in-app theme (MVP
/// is dark-only). The light (Paper) values live alongside them in
/// `brandkit/brandkit/tokens/hayati-tokens.json` for the future light theme;
/// the parity test pins the dark side to this file.
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

  // ── Redesign wave 1 (ui-ux §9.1) — the four gap-closing tokens ───────────

  /// Text/icons on [pomegranate] fills (4.7:1 — closes the recorded AA
  /// failure of sand-on-pomegranate at 3.94:1, frontend-brandkit §10 gap 1).
  /// Same value in both modes.
  static const Color moonlight = Color(0xFFFFF8F1);

  /// Secondary text: subtitles, captions, timestamps (7.9:1 on [night]).
  /// Closes gap #67 — Material's desaturated grey no longer leaks through
  /// Settings. Light (Paper) value: #6B6178.
  static const Color mist = Color(0xFFB9AFC6);

  /// Hairline dividers, borders, card edges — a non-text decorative-boundary
  /// role, deliberately below text contrast. Light (Paper) value: #E7DCCB.
  static const Color veil = Color(0xFF453A5C);

  /// Links, TextButtons, inline emphasis (6.8:1 on [night]) — color plus
  /// weight, never color alone. Closes frontend-brandkit §10 gap 2
  /// (pomegranate fails as text on night at 3.45:1). Light (Paper) value:
  /// #8E3140 (Pomegranate Deep, 7.2:1 on Paper).
  static const Color rose = Color(0xFFE38E99);
}
