import 'package:flutter/painting.dart';

/// Elevation constants realising redesign ui-ux §9.3's plum-tinted shadow spec.
///
/// Like `MotionTokens`, these are design-doc *rules* realised as code constants
/// rather than `hayati-tokens.json` entries (ADR-025 D5.ii status) — the JSON
/// schema carries colour/typography/spacing/radius only. §9.3: "Shadows are
/// plum-tinted, never black", three levels, dark values on the Night canvas:
///
///   Level 1 (cards)             y2  blur8  `#160E22` at 28%
///   Level 2 (sheets, dialogs)   y6  blur24 `#160E22` at 36%
///   Level 3 (milestone overlay) y12 blur40 `#160E22` at 44%
///
/// Material components can only approximate this through `elevation` +
/// `shadowColor` (Material derives its own blur/offset); widgets that own
/// their decoration (the seed vessel, reveal cards, milestone overlay) use
/// these exact `BoxShadow` lists instead. `elevation_tokens_test.dart` pins
/// the values.
abstract final class ElevationTokens {
  /// The plum shadow base — never black (§9.3).
  static const Color shadowBase = Color(0xFF160E22);

  /// Level 1 — cards. y2 blur8 at 28%.
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x47160E22), offset: Offset(0, 2), blurRadius: 8),
  ];

  /// Level 2 — sheets and dialogs. y6 blur24 at 36%.
  static const List<BoxShadow> level2 = [
    BoxShadow(color: Color(0x5C160E22), offset: Offset(0, 6), blurRadius: 24),
  ];

  /// Level 3 — the milestone overlay. y12 blur40 at 44%.
  static const List<BoxShadow> level3 = [
    BoxShadow(color: Color(0x70160E22), offset: Offset(0, 12), blurRadius: 40),
  ];
}
