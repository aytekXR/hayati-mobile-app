import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/motion_tokens.dart';

/// Motion is a brandkit §6 *rule* (a 150–300ms band + ease-out entering), not a
/// `hayati-tokens.json` token, so it is out of scope for the token-parity test
/// (ADR-025 D5.ii, same status as `minimumBodySize`/`dynamicTypeMax`). This
/// test is its checked, citable home: it pins the reveal duration inside §6's
/// band and the enter curve at ease-out, so a value edited outside the spec
/// turns red here rather than drifting silently past review.
void main() {
  group('MotionTokens (brandkit §6)', () {
    test(
      'the reveal unfold sits inside the 150–300ms micro-interaction band',
      () {
        expect(
          MotionTokens.revealUnfold.inMilliseconds,
          inInclusiveRange(150, 300),
        );
      },
    );

    test('the enter curve is ease-out (brandkit §6, "ease-out entering")', () {
      expect(MotionTokens.enter, Curves.easeOut);
    });

    test('the reveal slide is a modest, positive vertical rise', () {
      // A gentle rise — big enough to read as motion, small enough to stay a
      // micro-interaction (§6 "soft unfold", not a slam).
      expect(MotionTokens.revealSlide, greaterThan(0));
      expect(MotionTokens.revealSlide, lessThanOrEqualTo(24));
    });
  });

  group('MotionTokens — the reveal three-beat (redesign ui-ux §9)', () {
    test('the three beats fit the ≤1.2s choreography budget', () {
      final total =
          MotionTokens.revealBeatUnfold +
          MotionTokens.revealBeatSettle +
          MotionTokens.revealBeatSeedDrop;
      expect(total.inMilliseconds, lessThanOrEqualTo(1200));
    });

    test('each beat carries its §9 table value', () {
      // Pinned exactly: the beats are a signed spec, not a band — an edit is
      // a deliberate design change, red here first.
      expect(MotionTokens.revealBeatUnfold.inMilliseconds, 300);
      expect(MotionTokens.revealBeatSettle.inMilliseconds, 180);
      expect(MotionTokens.revealBeatSeedDrop.inMilliseconds, 420);
    });

    test('seedDrop is the one sanctioned spring; presses stay 120ms', () {
      expect(MotionTokens.seedDropCurve, Curves.easeOutBack);
      expect(MotionTokens.pressTouch.inMilliseconds, 120);
    });
  });
}
