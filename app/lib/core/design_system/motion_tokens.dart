import 'package:flutter/animation.dart';

/// Motion constants realising brandkit §6's reveal-interaction spec.
///
/// The brandkit defines motion as a RANGE + character in **prose** — §6:
/// "reveal moment = soft unfold + gentle haptic (this is *the* signature
/// interaction — budget polish here first)" and "micro-interactions 150–300ms,
/// ease-out entering / ease-in exiting" — NOT as a token in
/// `hayati-tokens.json` (whose keys are colour/typography/spacing/radius only).
///
/// So — exactly like `typography.minimumBodySize` and `typography.dynamicTypeMax`
/// (ADR-025 D5.ii, the four brandkit-JSON entries with no Dart counterpart) —
/// these are §6 *rules* realised as code constants, **enforced by review**, and
/// deliberately NOT asserted by `brandkit_token_parity_test.dart`. What keeps
/// them honest instead is `motion_tokens_test.dart`, which pins the duration
/// inside §6's 150–300ms band and the curve at ease-out, so an edit outside the
/// range turns red in a checked, citable place rather than drifting silently.
/// (ADR-025 slice 2, Session 029.)
abstract final class MotionTokens {
  /// The reveal "soft unfold" enter duration (brandkit §6, within 150–300ms).
  static const Duration revealUnfold = Duration(milliseconds: 240);

  /// Enter easing for micro-interactions (brandkit §6, "ease-out entering").
  static const Curve enter = Curves.easeOut;

  /// The reveal group's enter slide distance — a gentle rise, in dp. VERTICAL
  /// only, so it is direction-neutral and needs no RTL mirror variant.
  static const double revealSlide = 12;

  // ── The reveal three-beat choreography (redesign ui-ux §9 motion table) ───
  // The product's ONE choreography budget: partner's card unfolds toward
  // yours → both settle as a pair → one seed drops into the vessel. Total
  // ≤1.2s, pinned by `motion_tokens_test.dart`. Reduce-motion collapses the
  // whole sequence to an instant crossfade with the haptic preserved.

  /// Beat 1 — `unfoldReveal`: the partner card unfolds toward its pair.
  static const Duration revealBeatUnfold = Duration(milliseconds: 300);

  /// Beat 2 — `settlePair`: both cards settle as a pair (the light haptic
  /// fires at this settle).
  static const Duration revealBeatSettle = Duration(milliseconds: 180);

  /// Beat 3 — `seedDrop`: the seed into the vessel; also the solo-day seed
  /// fill. The one sanctioned spring (overshoot ≤4dp — keep travel small).
  static const Duration revealBeatSeedDrop = Duration(milliseconds: 420);

  /// The seed-drop's gentle spring character (§9 "gentle spring, overshoot
  /// ≤4dp"): easeOutBack overshoots ~10% of travel, so callers keep the drop
  /// distance ≤40dp for the ≤4dp budget to hold.
  static const Curve seedDropCurve = Curves.easeOutBack;

  /// All button presses — `pressTouch`: 120ms · easeOut · scale 0.98.
  static const Duration pressTouch = Duration(milliseconds: 120);
}
