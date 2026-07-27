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
