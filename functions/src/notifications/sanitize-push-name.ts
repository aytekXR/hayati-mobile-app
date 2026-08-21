// Bidi-safety for a partner display name interpolated into push copy
// (ADR-059 Decision 2, issue #136). The Functions-side twin of the app's
// `bidi_isolate.dart` — and deliberately a DIFFERENT mechanism, because the two
// seams are not the same seam.
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
function hasContent(text: string): boolean {
  return /[\p{L}\p{N}]/u.test(text);
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
  const trimmed = name?.trim();
  if (!trimmed) return undefined;

  // "A name with nothing in it is not a name" is a COPY rule, not a bidi one, so
  // it holds in every language: `...` must never reach the templates, or Turkish
  // renders "Partnerin ... cevapladı". The pre-existing `partnerName?.trim()`
  // guard let it through, and this test caught it.
  if (!hasContent(trimmed)) return undefined;

  if (!RTL_LANGUAGES.has(language)) return trimmed;

  const chars = [...trimmed];

  // A bracket is "matched" only if its partner is present somewhere on the other
  // side of it; anything else at an edge is a plain neutral. Computed over the
  // whole string rather than the edges alone, so `Ayşe (Y)` keeps both halves
  // while `Aylin (` keeps neither.
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
        open.splice(i, 1);
        return;
      }
    }
  });

  const keep = (index: number): boolean =>
    !isEdgeNeutral(chars[index]) || matched.has(index);

  let start = 0;
  let end = chars.length - 1;
  while (start <= end && !keep(start)) start += 1;
  while (end >= start && !keep(end)) end -= 1;
  if (start > end) return undefined;

  const result = chars.slice(start, end + 1).join('').trim();
  return hasContent(result) ? result : undefined;
}
