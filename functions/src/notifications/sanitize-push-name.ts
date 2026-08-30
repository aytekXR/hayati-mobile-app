// Safety for a partner display name interpolated into push copy — ADR-059
// Decision 2 (bidi) and ADR-065 Decision 3 (everything else).
//
// ⚠️ **THE CONTRACT WIDENED AT ADR-065 AND IS NOW A SECURITY BOUNDARY.** This
// used to return "a name with its RTL edge neutrals trimmed". It now returns
// "a name SAFE TO INTERPOLATE INTO OUTGOING PUSH COPY, or undefined", and bidi
// is one of FIVE concerns. The reason is #253: until it landed, `partnerName`
// was supplied by no caller, so nothing untrusted could reach here. It now
// carries a Firebase Auth `displayName` — a field the OTHER member of the
// couple sets, through a client SDK, with no server validation — onto this
// person's lock screen. Read the five rules below as a threat model, not as
// formatting.
//
// The Functions-side twin of the app's `bidi_isolate.dart` — and deliberately a
// DIFFERENT mechanism, because the two seams are not the same seam.
//
// WHY NOT THE ISOLATES. The app wraps a foreign-script run in U+2068/U+2069 at
// render (ADR-033). That is unavailable here for two reasons, neither of them
// convenience: ADR-033's own principle is "isolate for rendering, never for
// outgoing text", and a push payload is outgoing text — handed to FCM and APNs,
// logged by both, stored in a notification database on the device; and whether
// the OS notification shade honours the isolates at all is a DEVICE question
// nobody has been able to answer (#136 step 1, still open). Shipping invisible
// control characters into a payload on the hope that they help is exactly what
// that issue says not to do.
//
// WHAT BREAKS, MEASURED. In an RTL paragraph a bidi-NEUTRAL at the edge of an
// LTR run takes the PARAGRAPH's direction and detaches to the far side of the
// run — the #133 shape. Measured with FriBidi (`tool/bidi_visual.py`):
//
//     أجاب Aylin Y.   ->   .Aylin Y ﺏﺎﺟﺃ      (the period leads the name)
//     أجاب Aylin (    ->   ) Aylin ﺏﺎﺟﺃ       (and an unmatched bracket mirrors)
//
// In an LTR paragraph the same name is byte-identical logical-to-visual, which
// is why this runs for `ar` only — see `sanitizePushName`.

import type { PushLanguage } from './payload-policy';

/// The languages whose push copy is laid out right-to-left. A neutral at a
/// name's edge only misbehaves when the paragraph direction disagrees with the
/// name's own, so this is the condition the rule is actually about — not the
/// language, which is merely how we know the direction here.
const RTL_LANGUAGES: ReadonlySet<PushLanguage> = new Set<PushLanguage>(['ar']);

/// Bracket pairs, for the matched/unmatched distinction below.
const BRACKETS: ReadonlyMap<string, string> = new Map([
  ['(', ')'],
  ['[', ']'],
  ['{', '}'],
  ['‘', '’'],
  ['“', '”'],
]);

const CLOSERS: ReadonlySet<string> = new Set(BRACKETS.values());

/**
 * True when `ch` is a character that would take the paragraph's direction
 * rather than the name's — the ones that detach.
 *
 * ⚠️ **Neutrals only. NEVER "weak".** Unicode TR9's *weak* types include **EN
 * (European Number)**, so a rule written as "neutral or weak" strips digits —
 * `Aylin 2` would become `Aylin`, damaging a name to fix a defect digits do not
 * have. Measured: `أجاب John 3` renders `John 3 ﺏﺎﺟﺃ`, correct. An earlier draft
 * of ADR-059 specified "neutral or weak" and the design review caught it.
 *
 * Implemented as "not a letter, not a digit, not a mark" rather than by
 * enumerating punctuation, so a neutral nobody thought of is caught by
 * construction rather than by the completeness of a list.
 */
function isEdgeNeutral(ch: string): boolean {
  return !/[\p{L}\p{N}\p{M}]/u.test(ch);
}

/// Whether `text` contains anything a reader would recognise as a name.
///
/// Needed twice, and the second one is not obvious: a MATCHED bracket pair is
/// protected from trimming (see below), so `()` would otherwise survive the trim
/// with both characters intact and nothing between them — the edge case the
/// value table caught.
///
/// ⚠️ **A letter is not the same thing as a visible letter, and `\p{L}` alone
/// cannot tell them apart** (ADR-065 D3e). U+3164 HANGUL FILLER and its three
/// siblings (U+115F, U+1160, U+FFA0) are category **Lo** — Unicode says they are
/// letters — and they render as **nothing**. A name of five of them satisfied
/// "contains a letter" and composed `Your partner ␣␣␣␣␣ answered`: a gap where a
/// name should be, which is exactly the state the comment above says is not a
/// name. The disqualifier is the PROPERTY that means "renders as nothing"
/// (lesson 124, ADR-053) — `Default_Ignorable_Code_Point` — applied per rune, so
/// a name that merely CONTAINS one still counts on the strength of its real
/// letters. It cannot cost a real name a thing: a default-ignorable code point
/// has no glyph by definition, so no name is made of them.
function hasContent(text: string): boolean {
  return [...text].some((ch) => /[\p{L}\p{N}]/u.test(ch) && !IGNORABLE.test(ch));
}

/**
 * Trims the bidi-neutrals that would detach from `name`, or returns `undefined`
 * when nothing directional survives.
 *
 * **Runs for RTL copy only.** In an LTR paragraph a trailing `.` stays exactly
 * where it belongs (measured: `Aylin Y. answered today's question.` reorders not
 * at all), so trimming there would remove a character from a person's name for
 * no rendering benefit whatsoever. An earlier draft applied it to all three
 * languages for symmetry; the design review measured that symmetry and found it
 * to be a cost with no return.
 *
 * **A MATCHED bracket pair is preserved.** Unicode's paired-bracket rule
 * (N0/BD16) already resolves both halves to the enclosed text's direction, so
 * `Ayşe (Y)` renders correctly and stripping it would be damage with no benefit.
 * An UNMATCHED bracket is an ordinary neutral, jumps like a period, and mirrors
 * on the way — `Aylin (` renders as `) Aylin` — so it is trimmed.
 *
 * Returning `undefined` for a name with nothing strong left routes the caller to
 * the EXISTING name-free copy, which is already written and already tested. This
 * function never invents a fallback of its own.
 */
export function sanitizePushName(
  name: string | undefined,
  language: PushLanguage,
): string | undefined {
  if (name === undefined) return undefined;

  // ADR-065 D3a/D3e/D3b, in order. All three run for EVERY language: a newline
  // injects a line, an RLO reverses a sentence and a half-character is not text,
  // regardless of which way the copy leans — unlike the edge trim below, which is
  // a genuinely RTL-only concern.
  const normalized = capMarkRuns(stripUnsafe(name));
  if (!normalized) return undefined;

  // "A name with nothing in it is not a name" is a COPY rule, not a bidi one, so
  // it holds in every language: `...` must never reach the templates, or Turkish
  // renders "Partnerin ... cevapladı". The pre-existing `partnerName?.trim()`
  // guard let it through, and this test caught it.
  if (!hasContent(normalized)) return undefined;

  // ADR-065 D3c. BEFORE the edge trim, so that whether a name is usable at all
  // is language-independent; only its trimming is not.
  if ([...normalized].length > MAX_NAME_CODE_POINTS) return undefined;

  if (!RTL_LANGUAGES.has(language)) return normalized;

  const result = trimEdges([...normalized]);
  return result !== undefined && hasContent(result) ? result : undefined;
}

/**
 * The edge trim, as its own function because it **recurses**.
 *
 * A name wrapped entirely in a matched pair keeps its brackets (N0 protects
 * them) — but the content inside is then itself at the edge of the LTR run, and
 * its own neutrals detach exactly as before. Measured: `أجاب (Aylin Y.)` renders
 * `(.Aylin Y) ﺏﺎﺟﺃ` — the period lands *inside* the bracket, at position 1. The
 * brackets being safe does not make what they contain safe, and the built-diff
 * review found this by testing a case the first draft's example did not have
 * (`Ayşe (Y)` has no neutral inside to detach).
 */
function trimEdges(chars: readonly string[]): string | undefined {
  if (chars.length === 0) return undefined;
  const matched = matchedBracketIndices(chars);
  const keep = (index: number): boolean =>
    !isEdgeNeutral(chars[index]) || matched.has(index);

  let start = 0;
  let end = chars.length - 1;
  while (start <= end && !keep(start)) start += 1;
  while (end >= start && !keep(end)) end -= 1;
  if (start > end) return undefined;

  // Wrapped in its own matched pair? Then trim what is inside it, too.
  if (matched.has(start) && matched.has(end) && BRACKETS.get(chars[start]) === chars[end]) {
    const inner = trimEdges(chars.slice(start + 1, end));
    if (inner === undefined) return undefined;
    return `${chars[start]}${inner}${chars[end]}`.trim();
  }
  return chars.slice(start, end + 1).join('').trim();
}

/**
 * The indices of brackets that form a **properly nested** pair — the only ones
 * Unicode's N0/BD16 protects.
 *
 * ⚠️ **`open.length = i`, not `open.splice(i, 1)`.** Closing a bracket discards
 * every bracket opened *after* its partner; a version that removed only the
 * partner called `(A [B)]` fully matched, while N0 leaves the `]` unpaired — and
 * measured, that `]` jumps to the head of the line and mirrors into a `[`, which
 * is the exact defect this function exists to prevent. The first draft had the
 * `splice`, and the built-diff review measured it wrong.
 */
function matchedBracketIndices(chars: readonly string[]): ReadonlySet<number> {
  const matched = new Set<number>();
  const open: { ch: string; index: number }[] = [];
  chars.forEach((ch, index) => {
    if (BRACKETS.has(ch)) {
      open.push({ ch, index });
      return;
    }
    if (!CLOSERS.has(ch)) return;
    for (let i = open.length - 1; i >= 0; i -= 1) {
      if (BRACKETS.get(open[i].ch) === ch) {
        matched.add(open[i].index);
        matched.add(index);
        open.length = i;
        return;
      }
    }
  });
  return matched;
}

/// Characters that SEPARATE: the C0/C1 controls (where `\n`, `\r` and `\t`
/// live) and the explicit line/paragraph separators.
///
/// ⚠️ **NON-GLOBAL, and every regex `.test()`ed in this file must be.** A `/g`
/// regex carries `lastIndex` across `.test()` calls, so alternate matches are
/// SKIPPED. Measured while designing ADR-065: a draft of `stripUnsafe` used a
/// global regex and returned `Aylin\nSecurity alert` from a two-newline input —
/// one newline removed, one left in, which reads exactly like a working strip
/// (lesson 136). The only global regex here is WHITESPACE_RUN, which is
/// `.replace()`d and never `.test()`ed.
const SEPARATOR = /[\p{Cc}\p{Zl}\p{Zp}]/u;

/// Characters that are INVISIBLE: Unicode's format category.
///
/// The PROPERTY rather than a list (lesson 124, ADR-053), and that is what makes
/// it durable. It covers all twelve UAX #9 explicit formatting characters —
/// U+061C, U+200E, U+200F, U+202A–U+202E, U+2066–U+2069, the ones that reorder a
/// paragraph, and the two that ADR-059 D3 promised would never enter a payload —
/// and also the invisibles an enumeration would have missed: U+00AD soft hyphen,
/// U+2060 word joiner, U+FEFF, and U+FFF9–U+FFFB, the interlinear annotation
/// characters, which exist to hide text behind other text.
const INVISIBLE = /\p{Cf}/u;

/// The two format characters a name may legitimately carry.
///
/// **ZWNJ (U+200C) is orthography, not decoration** — Persian and Urdu require it
/// inside ordinary words, so stripping it damages a real person's name. **ZWJ
/// (U+200D)** joins emoji sequences. Neither can introduce a line or reorder a
/// paragraph, which is what INVISIBLE is here to stop.
const KEEP_INVISIBLE = /[\u200C\u200D]/u;

/// A code point that is defined to RENDER AS NOTHING (ADR-065 D3e).
///
/// Used only by `hasContent`, to disqualify a character from counting as the
/// name's content — never to delete one, because the set includes characters
/// real orthography carries (U+17B4/U+17B5 in Khmer, the variation selectors).
/// A name containing one keeps it; a name made ONLY of them is not a name.
///
/// The property, not the four Hangul fillers that exposed the gap: it is the
/// only thing that says "no glyph" for a category-`Lo` code point, and an
/// enumeration would go stale the way the twelve-bidi-control list would have
/// (lesson 124).
const IGNORABLE = /\p{Default_Ignorable_Code_Point}/u;

/// An UNPAIRED surrogate — half of a character, and not text at all (ADR-065 D3e).
///
/// ⚠️ **Matches only LONE surrogates, never a valid pair.** Under the `u` flag
/// the engine iterates CODE POINTS, so `😀` is one `So` code point and does not
/// match; `'\uD800'` alone is one `Cs` code point and does. Measured, because a
/// version of this that ate emoji would be a worse defect than the one it fixes.
///
/// `displayName` reaches us as a JSON string, and JSON can carry `"\ud800"` — a
/// string JavaScript accepts and `String.prototype.isWellFormed()` rejects. Left
/// in, it either lands on the lock screen as `�` (any UTF-8 round trip
/// replaces it) or is refused by FCM, which `deliverPush` counts as
/// `send-failed` — the recipient silently gets NOTHING. That second outcome is
/// the one D3c's length cap exists to prevent, reached by a different door, so
/// it is bounded here rather than conceded.
const MALFORMED = /\p{Cs}/u;

/// A combining mark (ADR-065 D3b).
const COMBINING_MARK = /\p{M}/u;

/// Runs of whitespace, `\p{Zs}` included so U+00A0 and U+3000 collapse too.
/// The one global regex in this file — `.replace()`d, never `.test()`ed.
const WHITESPACE_RUN = /[\s\p{Zs}]+/gu;

/// The longest run of combining marks a name may carry between base characters.
///
/// Measured (ADR-065 D3b): fully-pointed Hebrew, Hebrew with cantillation,
/// Vietnamese precomposed AND decomposed, `José` in NFD, Arabic with full
/// tashkeel, Thai and Devanagari are all byte-unchanged at a cap of **four** —
/// none of them reaches four consecutive marks on one base. Eight is pure
/// margin, and it costs nothing measured. What it stops is the smear: a name of
/// one base and a thousand marks becomes thirteen code points.
///
/// This is NOT "strip \p{M}", and the difference is the whole decision. The
/// design review refuted the blanket rule correctly — `José` in NFD is `Jose`
/// plus U+0301 — and capping a RUN leaves every case that refutation named intact.
const MAX_MARK_RUN = 8;

/// The most code points a display name may carry and still be interpolated.
///
/// A **product** bound, deliberately not the safety bound — the safety bound is
/// `stripUnsafe`. It sits above the app's own input cap (`nameCaptureMaxLength`
/// is **50**, so a server bound below that would silently discard names the app
/// itself invites people to type) and far below the point where the payload is
/// at risk: 64 code points is at most 256 UTF-8 bytes, against a ~4KB FCM/APNs
/// ceiling that a long enough name would breach — and a breach there is a FAILED
/// SEND, not a cosmetic problem. Because it is not load-bearing, a value that is
/// slightly wrong costs a name-free push rather than a broken one.
const MAX_NAME_CODE_POINTS = 64;

/**
 * ADR-065 D3a (separators, invisibles) and D3e (unpaired surrogates). Maps
 * separators to a space, deletes invisibles and half-characters, collapses
 * whitespace runs, trims.
 *
 * **The two halves map DIFFERENTLY and that is deliberate.** A draft of this
 * deleted both; measured, deleting `\n` turns `Aylin\nSecurity` into
 * `AylinSecurity` — two words silently welded into one nobody typed. Separators
 * separate, so they become a space; format characters occupy no width, so a
 * space would invent one. An unpaired surrogate is neither: it is a broken half
 * of one character, so it is deleted with the invisibles rather than spaced.
 *
 * Iterates RUNES, never code units.
 */
function stripUnsafe(text: string): string {
  const mapped = [...text]
    .map((ch) => {
      if (SEPARATOR.test(ch)) return ' ';
      if (MALFORMED.test(ch)) return '';
      if (INVISIBLE.test(ch) && !KEEP_INVISIBLE.test(ch)) return '';
      return ch;
    })
    .join('');
  return mapped.replace(WHITESPACE_RUN, ' ').trim();
}

/**
 * ADR-065 D3b. Truncates any run of more than MAX_MARK_RUN combining marks.
 *
 * The counter resets on every non-mark, so the cap is per RUN — which is what
 * makes it invisible to real orthography (a name is base-mark-base-mark, never
 * base-mark×200) while bounding the one shape that is not.
 */
function capMarkRuns(text: string): string {
  let run = 0;
  return [...text]
    .filter((ch) => {
      if (COMBINING_MARK.test(ch)) {
        run += 1;
        return run <= MAX_MARK_RUN;
      }
      run = 0;
      return true;
    })
    .join('');
}
