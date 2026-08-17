import 'dart:ui' show TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/l10n/bidi_isolate.dart';
import 'package:hayati_app/core/l10n/strong_bidi_ranges.dart';
import 'package:intl/intl.dart' show Bidi;

/// The strong-RTL table and the first-strong scan built on it (ADR-053, #137).
///
/// WHAT WENT WRONG. `isolateWithin` asked `intl` which way a string leans.
/// `intl`'s RTL class is `֑-߿יִ-﷽ﹰ-ﻼ` and its LTR
/// class covers `ࠀ-῿` — so the whole **U+0800–U+08C9** region
/// (Samaritan, Mandaic, Syriac Supplement, Arabic Extended-A and -B) is
/// strong-RTL by Unicode and strong-LTR by `intl`. `intl` documents the trade at
/// the constant: *"simplified for performance and small code size."*
///
/// The failure was **one-directional and silent**, which is why it was filed
/// rather than absorbed: in RTL chrome the seam isolated anyway and `FSI`
/// resolved by the real first-strong character, so it was correct by accident.
/// In LTR chrome it emitted nothing and the mirror defect survived with nothing
/// going red.
void main() {
  group('the generated table', () {
    test('is sorted, non-overlapping and well-formed', () {
      expect(
        strongRtlRanges.length.isEven,
        isTrue,
        reason: 'flat pairs — an odd length means a truncated generation',
      );
      // A table that has quietly become empty is the greenest possible input to
      // every test below, so the floor is asserted before anything reads it.
      expect(strongRtlRanges.length ~/ 2, greaterThan(100));
      for (var i = 0; i < strongRtlRanges.length; i += 2) {
        expect(
          strongRtlRanges[i],
          lessThanOrEqualTo(strongRtlRanges[i + 1]),
          reason: 'range $i is inverted',
        );
        if (i > 0) {
          expect(
            strongRtlRanges[i - 1],
            lessThan(strongRtlRanges[i]),
            reason:
                'ranges must be sorted and disjoint — the binary search in '
                'isStrongRtl depends on it',
          );
        }
      }
    });

    test('the LTR table is sorted, non-overlapping and well-formed too', () {
      expect(strongLtrRanges.length.isEven, isTrue);
      expect(strongLtrRanges.length ~/ 2, greaterThan(500));
      for (var i = 0; i < strongLtrRanges.length; i += 2) {
        // Within the pair. Asserted here and not only between pairs: an
        // inverted range makes `_inRanges` return false for every rune it was
        // supposed to match, which is a silent miss rather than a crash.
        expect(
          strongLtrRanges[i],
          lessThanOrEqualTo(strongLtrRanges[i + 1]),
          reason: 'LTR range $i is inverted',
        );
        if (i > 0) {
          expect(
            strongLtrRanges[i - 1],
            lessThan(strongLtrRanges[i]),
            reason: 'LTR ranges must be sorted and disjoint',
          );
        }
      }
    });

    // THE LOAD-BEARING ASSERTION, and the reason this scans all 1.1M code
    // points rather than sampling: the two tables must be DISJOINT. A code
    // point in both would make `firstStrongDirection` order-dependent, i.e.
    // would make the answer depend on which `if` came first — which is exactly
    // the accident that made `intl` usable at all and wrong at the edges.
    test('the two strong classes are disjoint', () {
      final both = <int>[];
      for (var cp = 0; cp <= 0x10FFFF; cp++) {
        if (isStrongRtl(cp) && isStrongLtr(cp)) both.add(cp);
      }
      expect(both, isEmpty);
    });

    // Every character this product actually renders must land in exactly one
    // bucket, and the neutral bucket must be genuinely neutral.
    test(
      'classifies the scripts this product ships, and neutrals as neither',
      () {
        for (final cp in [0x0041, 0x0131, 0x011F]) {
          expect(
            isStrongLtr(cp),
            isTrue,
            reason: 'Latin/Turkish U+${cp.toRadixString(16)}',
          );
          expect(isStrongRtl(cp), isFalse);
        }
        for (final cp in [0x0627, 0x0628, 0x06CC]) {
          expect(
            isStrongRtl(cp),
            isTrue,
            reason: 'Arabic U+${cp.toRadixString(16)}',
          );
          expect(isStrongLtr(cp), isFalse);
        }
        // Digits, punctuation and emoji are weak or neutral — no direction.
        for (final cp in [0x0032, 0x002E, 0x2026, 0x1F642]) {
          expect(isStrongRtl(cp), isFalse, reason: 'U+${cp.toRadixString(16)}');
          expect(isStrongLtr(cp), isFalse, reason: 'U+${cp.toRadixString(16)}');
        }
      },
    );

    // The blocks #137 named, plus the three it did not — each one a character
    // `intl` called LTR while Unicode calls it strong-RTL.
    test(
      'covers the whole region intl misread, not just Arabic Extended-A',
      () {
        for (final entry in {
          0x0800: 'SAMARITAN LETTER ALAF',
          0x0840: 'MANDAIC LETTER HALQA',
          0x0860: 'SYRIAC LETTER MALAYALAM NGA',
          0x0870: 'ARABIC LETTER ALEF WITH ATTACHED FATHA (Extended-B)',
          0x08A0: 'ARABIC LETTER BEH WITH SMALL V BELOW (Extended-A)',
          0x08B5: 'the second character #137 measured',
          0x1E900: 'ADLAM CAPITAL LETTER ALIF (astral)',
          0x10800: 'CYPRIOT SYLLABLE A (astral)',
        }.entries) {
          expect(
            isStrongRtl(entry.key),
            isTrue,
            reason: 'U+${entry.key.toRadixString(16)} ${entry.value}',
          );
          expect(
            Bidi.startsWithLtr(String.fromCharCode(entry.key)),
            isTrue,
            reason:
                'the bug this replaces: intl still calls '
                'U+${entry.key.toRadixString(16)} LTR',
          );
        }
      },
    );
  });

  group('firstStrongDirection', () {
    test('reads Arabic Extended-A as RTL, where intl read LTR', () {
      const beh = 'ࢠ'; // ARABIC LETTER BEH WITH SMALL V BELOW, Bidi AL
      expect(Bidi.startsWithLtr(beh), isTrue, reason: 'the bug, still present');
      expect(firstStrongDirection(beh), TextDirection.rtl); // rtl-ok
    });

    // ASTRAL. `intl` matches with a UTF-16 regex, so an astral character is
    // tested through its high surrogate — and every high surrogate sits inside
    // intl's LTR class. Iterating runes is what fixes this, and it is a
    // different bug from the range gap even though it presents identically.
    test('reads astral RTL as RTL, where the surrogate read LTR', () {
      const adlam = '\u{1E900}'; // ADLAM CAPITAL LETTER ALIF, Bidi R
      expect(
        Bidi.startsWithLtr(adlam),
        isTrue,
        reason: 'the surrogate bug, still present in intl',
      );
      expect(firstStrongDirection(adlam), TextDirection.rtl); // rtl-ok
    });

    test('still reads the scripts this product actually ships', () {
      expect(firstStrongDirection('Kahvaltıda'), TextDirection.ltr); // rtl-ok
      expect(firstStrongDirection('القهوة'), TextDirection.rtl); // rtl-ok
      expect(firstStrongDirection('coffee'), TextDirection.ltr); // rtl-ok
    });

    test('skips neutrals to reach the first STRONG character', () {
      expect(firstStrongDirection('… ࢠ'), TextDirection.rtl); // rtl-ok
      expect(firstStrongDirection('“2026” hello'), TextDirection.ltr); // rtl-ok
    });

    test('returns null when there is no strong character at all', () {
      expect(firstStrongDirection('2026'), isNull);
      expect(firstStrongDirection('…'), isNull);
      expect(firstStrongDirection('🙂'), isNull);
    });
  });

  group('isolateWithin — the silent case #137 was filed for', () {
    test('LTR chrome now isolates Arabic Extended-A content', () {
      const text = 'ࢠࢡ.';
      // Before ADR-053 this returned `text` unchanged: intl called it LTR, the
      // seam saw agreement with the paragraph, and the trailing '.' stayed on
      // the wrong end with nothing going red.
      expect(
        isolateWithin(text, TextDirection.ltr), // rtl-ok
        '$firstStrongIsolate$text$popDirectionalIsolate',
      );
    });

    test('RTL chrome leaves it alone — it agrees with the paragraph', () {
      const text = 'ࢠࢡ.';
      expect(isolateWithin(text, TextDirection.rtl), text); // rtl-ok
    });

    // The pixel-neutrality argument in `isolateWithin`'s own doc: an
    // unconditional seam moved 27 goldens for no behavioural gain. Widening the
    // RTL class must not quietly turn the predicate into "always isolate".
    test('agreement still emits NOTHING, in both directions', () {
      expect(isolateWithin('coffee', TextDirection.ltr), 'coffee'); // rtl-ok
      expect(isolateWithin('القهوة', TextDirection.rtl), 'القهوة'); // rtl-ok
    });

    test('disagreement still isolates, in both directions', () {
      expect(
        isolateWithin('coffee.', TextDirection.rtl), // rtl-ok
        '${firstStrongIsolate}coffee.$popDirectionalIsolate',
      );
      expect(
        isolateWithin('القهوة.', TextDirection.ltr), // rtl-ok
        '$firstStrongIsolate'
        'القهوة.'
        '$popDirectionalIsolate',
      );
    });
  });
}
