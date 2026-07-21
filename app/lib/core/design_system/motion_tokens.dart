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
}
