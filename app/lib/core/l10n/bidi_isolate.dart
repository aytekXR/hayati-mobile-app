/// Unicode bidi isolation for text whose script we do not control (ADR-033).
///
/// A bidi-neutral character (`.` `?` `!` `…` `:`) sitting at the boundary of a
/// run whose direction differs from the paragraph's takes the **paragraph's**
/// direction unless it is isolated. That is the Unicode Bidirectional
/// Algorithm working correctly — it is our input that is under-specified. The
/// visible result was issue #133: a Turkish answer inside the Arabic chrome
/// rendering as `.Kahvaltıda birlikte gülmemiz`.
///
/// The fix is one pair of characters around the run. See ADR-033 D1 for why
/// this sits at the STRING boundary rather than on the widget: a widget-level
/// `Directionality`/`textDirection` sets a whole paragraph, and cannot isolate
/// a partner's display name interpolated into the MIDDLE of an Arabic sentence
/// (`دعاك {name}`), which is a real call site.
library;

import 'dart:ui' show TextDirection;

import 'strong_bidi_ranges.dart';

/// U+2068 FIRST STRONG ISOLATE — opens a run whose direction is taken from its
/// own first strong character, exactly like HTML's `dir="auto"`.
/// Written as an escape, not as the literal character: the analyzer flags a
/// raw U+2068 in source (`text_direction_code_point_in_literal`), and rightly —
/// an invisible control in a string literal is exactly the thing a reader
/// cannot review.
const String firstStrongIsolate = '\u2068';

/// U+2069 POP DIRECTIONAL ISOLATE — closes the innermost open isolate.
const String popDirectionalIsolate = '\u2069';

/// Wraps [text] so its own first strong character decides its direction, and
/// its bidi-neutrals bind to it rather than to the surrounding paragraph.
///
/// Deliberately NOT `intl`'s `Bidi` helpers:
///   * `intl` exposes only the deprecated *embedding* controls (LRE/RLE/PDF),
///     never FSI/PDI;
///   * `Bidi.detectRtlDirectionality` is a **majority-of-strong-characters**
///     heuristic, not first-strong, and the two disagree in both directions
///     (`'العربية is a beautiful language.'` → `startsWithRtl` true,
///     `detectRtlDirectionality` false). We resolve nothing ourselves; the
///     platform's Unicode implementation does it.
///
/// A no-op when [text] is empty — two invisible controls around nothing help
/// no one and would still cost layout width (see below).
///
/// **Do not pair this with `letterSpacing`.** Flutter applies letter-spacing
/// after the zero-width isolate controls too, so an isolated string measures
/// `2 × letterSpacing` wider than the same string bare — measured at 144.0 →
/// 152.0 px for an eight-character code at `letterSpacing: 4`. That is why the
/// invite code is deliberately NOT isolated (ADR-033 D3): its alphabet holds no
/// bidi-neutral, so it has nothing to isolate and everything to lose.
String isolate(String text) =>
    text.isEmpty ? text : '$firstStrongIsolate$text$popDirectionalIsolate';

/// Whether [rune] falls in one of [ranges]' flat `[start, end]` pairs.
///
/// Binary search; no allocation per call, which matters because this runs per
/// character at a render seam.
bool _inRanges(int rune, List<int> ranges) {
  var lo = 0;
  var hi = ranges.length ~/ 2 - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (rune < ranges[mid * 2]) {
      hi = mid - 1;
    } else if (rune > ranges[mid * 2 + 1]) {
      lo = mid + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// Whether [rune] is strongly right-to-left — Bidi_Class **R or AL**.
bool isStrongRtl(int rune) => _inRanges(rune, strongRtlRanges);

/// Whether [rune] is strongly left-to-right — Bidi_Class **L**.
bool isStrongLtr(int rune) => _inRanges(rune, strongLtrRanges);

/// The first strongly-directional character's direction, or null when [text]
/// has none (a bare `'2026'`, `'…'`, an emoji).
///
/// **`intl` is gone from this seam, and that is the fix** (ADR-053, #137). Its
/// two character classes are approximations *in both directions* — it documents
/// the trade at the constant itself: *"not completely correct according to the
/// Unicode standard… simplified for performance and small code size."* Measured
/// exhaustively against intl 0.20.2, the pinned version:
///
///   * **150** strong-RTL code points it classifies as strong-**LTR** — the
///     whole `U+0800–U+08C9` region (Samaritan, Mandaic, Syriac Supplement,
///     Arabic Extended-A **and** -B). This is issue #137, and it is wider than
///     the issue's Arabic-Extended-A-only description.
///   * **1,783** strong-RTL code points its RTL class does not reach at all.
///   * **322** code points in its RTL class that are not strong-RTL, and
///     **3,308** in its LTR class that are not strong-LTR.
///
/// That is a fair trade for `Bidi.startsWithLtr`, which only ever has to pick
/// one of two. It is not a basis for a three-way answer, where both classes
/// being loose means the neutral case is decided by whichever loose test fired.
///
/// **Iterates RUNES, not code units, and that is a SECOND fix.** `intl` matches
/// with a UTF-16 regex, so an astral character is tested through its surrogates
/// — and every high surrogate (`U+D800–U+DBFF`) sits inside `intl`'s LTR class.
/// So every astral RTL script (Adlam, Cypriot, Old Hungarian) read as LTR, and
/// so did an emoji, through the surrogate that happened to lead it.
///
/// The third answer is the one that could not be expressed before: a string
/// with **no strong character** has no direction of its own and must take the
/// paragraph's, which is what it already does. Forcing an isolate there would
/// pin it to LTR and be actively wrong in Arabic chrome.
TextDirection? firstStrongDirection(String text) {
  for (final rune in text.runes) {
    if (isStrongRtl(rune)) return TextDirection.rtl; // rtl-ok
    if (isStrongLtr(rune)) return TextDirection.ltr; // rtl-ok
  }
  return null;
}

/// [isolate], but ONLY when the isolate would actually do something: when
/// [text]'s own first-strong direction differs from the [ambient] paragraph's.
///
/// **This is what call sites should use.** Isolating unconditionally is
/// semantically harmless — an isolate whose direction already matches the
/// paragraph resolves to the same thing — but it is NOT pixel-neutral. The
/// control characters split the shaping run, and the re-shaped glyphs differ at
/// the sub-pixel level: measured over the golden suite, an unconditional seam
/// moved **27 `tr.ltr`/`en.ltr` goldens** by ~0.8% of their pixels (mean delta
/// 27/255, no reflow, no size change) for no behavioural gain. Under this
/// predicate those cells are byte-identical, and the only goldens that move are
/// the ones carrying the defect.
///
/// Returns [text] unchanged when it has **no strong character at all** (a bare
/// `'2026'`, `'…'`, an emoji). Such a string has no direction of its own, so it
/// should take the paragraph's — which is what it already does. Forcing an
/// isolate there would pin it to LTR and could be actively wrong in Arabic
/// chrome.
///
/// First-strong is decided by [firstStrongDirection] against the generated
/// Unicode tables, NOT by `intl` — see that function for what `intl` got wrong
/// and why the third answer (no direction at all) is the one that matters here.
String isolateWithin(String text, TextDirection ambient) {
  if (text.isEmpty) return text;
  // rtl_lint bans bare TextDirection literals because they are almost always a
  // physical-layout mistake. This one is a LOGICAL direction comparison at the
  // one seam that exists to reason about direction, so it takes the documented
  // escape rather than pretending the comparison can be written without it.
  final ambientIsRtl = ambient == TextDirection.rtl; // rtl-ok
  final own = firstStrongDirection(text);
  if (own == null) return text;
  final ownIsRtl = own == TextDirection.rtl; // rtl-ok
  return ownIsRtl == ambientIsRtl ? text : isolate(text);
}
