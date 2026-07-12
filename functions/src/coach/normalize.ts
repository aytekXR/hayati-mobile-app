// Pure text normalizer for the M5.1 coach crisis detector (ADR-016 Decision 3).
// One code path is applied IDENTICALLY to lexicon entries at build time and to
// input text at match time, so the matcher and its data can never skew — the
// class of "seed folds one way, input another" bugs is structurally excluded.
// Total functions over plain strings: no Firestore, no I/O, no throws on any
// input (including lone surrogates), so evasion resistance is exhaustively
// unit- and property-testable without the emulator (the streak.ts mold).
//
// The pipeline is ADR-016 Decision 3 steps 1-9. Every fold is monotone or
// over-triggering by construction — the asymmetry of harms (a missed crisis is
// dangerous; a spurious help path merely costs a persona reply) decides the
// design, so every transform widens the match surface, never narrows it. Each
// step has ONE red lever in coach-normalize.test.ts: remove the step and a
// case goes red.
//
// All Arabic / format-character ranges are written as \u escapes (never literal
// invisibles) so the code points are auditable and the tashkeel range can never
// silently swallow the adjacent Arabic-Indic digit block.

/**
 * The ordered fold-step registry (ADR-016 Decision 3 steps 1-9). Exported so the
 * unit suite can assert the pipeline's shape and so a reviewer can map each test
 * block to its step. `collapse-repetition`/`forms`/`leet-variants` are applied at
 * the FORM level (see matchVariants) rather than as raw-string passes — folding
 * repetition AFTER the leet fold is what keeps token equality monotone (a leet
 * "pa5s" and a plain "pass" both collapse to "pas").
 */
export const NORMALIZER_STEPS = [
  'nfkc',
  'strip-format',
  'fold-arabic',
  'fold-digits',
  'turkish-casefold',
  'fold-homoglyphs',
  'collapse-repetition',
  'forms',
  'leet-variants',
] as const;

export type NormalizerStep = (typeof NORMALIZER_STEPS)[number];

/**
 * The leet substitution table (ADR-016 Decision 3 step 9). Deliberately does NOT
 * include 2/6/9 — those carry no common Latin homoglyph, and mapping them would
 * corrupt Arabizi (where 3=ع, 7=ح, 5=خ are LETTERS). The corruption risk is why
 * the leet fold is a SEPARATE variant, never a baked-in step: matching runs
 * against both the folded and the unfolded forms so "3ayez amout" stays matchable
 * by an Arabizi seed in its unfolded form (step 9 rationale).
 */
const LEET_MAP: Readonly<Record<string, string>> = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '8': 'b',
  '@': 'a',
  $: 's',
  '!': 'i',
};

/**
 * Common Cyrillic/Greek → Latin confusables (ADR-016 Decision 3 step 6), keyed by
 * their LOWERCASE code point (the casefold in step 5 runs first, so only
 * lowercase forms reach here). Conservative: only glyphs that are visually
 * identical to a Latin letter, so folding them can never invent a match a human
 * reader would not also see.
 */
const HOMOGLYPH_MAP: Readonly<Record<string, string>> = {
  // Cyrillic
  'а': 'a', // а
  'е': 'e', // е
  'о': 'o', // о
  'с': 'c', // с
  'р': 'p', // р
  'у': 'y', // у
  'х': 'x', // х
  'к': 'k', // к
  'і': 'i', // і (Cyrillic dotted i)
  'ј': 'j', // ј (Cyrillic je)
  'ѕ': 's', // ѕ (Cyrillic dze)
  // Greek
  'ο': 'o', // ο
  'α': 'a', // α
  'ε': 'e', // ε
  'ρ': 'p', // ρ
  'ι': 'i', // ι
  'κ': 'k', // κ
  'ν': 'v', // ν
  'τ': 't', // τ
};

const CYRILLIC_GREEK_PATTERN = new RegExp(`[${Object.keys(HOMOGLYPH_MAP).join('')}]`, 'gu');
const LEET_PATTERN = /[0134578@$!]/g;
const REPETITION_PATTERN = /(\p{L})\1+/gu;

/**
 * Step 2: strip the full Unicode `Cf` category (ZWJ/ZWNJ/ZWSP, directional
 * marks, U+FEFF, soft hyphen, U+2060-2064, …) PLUS variation selectors
 * U+FE00-FE0F. The variation selectors are a separate clause because they are
 * category Mn (nonspacing mark), not Cf, so `\p{Cf}` alone would miss them
 * (verified). Tatweel U+0640 is a printable letter modifier and is handled in
 * step 3, not here.
 */
function stripFormat(s: string): string {
  return s.replace(/\p{Cf}/gu, '').replace(/[︀-️]/g, '');
}

/**
 * Step 3: Arabic orthographic folding. Strips tashkeel (U+064B-065F and the
 * superscript alef U+0670) and tatweel (U+0640); folds the alef variants and the
 * ى/ة letters to their bare forms; folds the hamza CARRIERS ؤ→و and ئ→ي and
 * strips the bare hamza ء. Hamza-dropping is routine casual Arabic typing, so a
 * seed carrying ؤ/ئ/ء must still match hamza-less input (Decision 3 finding).
 * The tashkeel class stops at U+065F ON PURPOSE — U+0660-0669 is the Arabic-Indic
 * digit block, folded (not stripped) one step later.
 */
function foldArabic(s: string): string {
  return s
    .replace(/[ً-ٰٟ]/g, '') // tashkeel + superscript alef
    .replace(/ـ/g, '') // tatweel
    .replace(/[أإآٱ]/g, 'ا') // أ إ آ ٱ → ا
    .replace(/ى/g, 'ي') // ى → ي
    .replace(/ة/g, 'ه') // ة → ه
    .replace(/ؤ/g, 'و') // ؤ → و
    .replace(/ئ/g, 'ي') // ئ → ي
    .replace(/ء/g, ''); // bare hamza ء → strip
}

/**
 * Step 4: Arabic-Indic (U+0660-0669) and Extended Arabic-Indic (U+06F0-06F9)
 * digits fold to ASCII 0-9. Runs BEFORE the leet variant so an Arabic-Indic ٣
 * and a Latin 3 are one code point by the time leet folding sees them.
 */
function foldDigits(s: string): string {
  return s.replace(/[٠-٩۰-۹]/g, (c) => {
    const code = c.codePointAt(0) as number;
    const base = code >= 0x06f0 ? 0x06f0 : 0x0660;
    return String(code - base);
  });
}

/**
 * Step 5: casefold with Turkish I-rules, then the Turkish ASCII diacritic fold.
 * The I-family is mapped BEFORE the generic lowercase because JS's
 * locale-independent `toLowerCase` mangles it: `'İ'.toLowerCase()` yields
 * `'i' + U+0307` (combining dot) and `'ı'` stays dotless (verified). So:
 *   İ → i, I → ı  (Turkish upper→lower), then lowercase the rest, then ı → i so
 *   the dotted/dotless i's collapse into ONE bucket `i`.
 * Then ç/ş/ğ/ö/ü → c/s/g/o/u: diacritic-less typing is the Turkish norm, so
 * "kendimi oldurecegim" must match a seed "kendimi öldüreceğim" (blocking
 * finding). The uppercase Ç/Ş/Ğ/Ö/Ü lowercase cleanly under the generic pass
 * before this fold sees them.
 */
function turkishCasefold(s: string): string {
  return s
    .replace(/İ/g, 'i') // İ → i
    .replace(/I/g, 'ı') // I → ı
    .toLowerCase()
    .replace(/ı/g, 'i') // ı → i (single bucket)
    .replace(/ç/g, 'c') // ç → c
    .replace(/ş/g, 's') // ş → s
    .replace(/ğ/g, 'g') // ğ → g
    .replace(/ö/g, 'o') // ö → o
    .replace(/ü/g, 'u'); // ü → u
}

/** Step 6: fold the Cyrillic/Greek confusables to Latin (lowercase forms only). */
function foldHomoglyphs(s: string): string {
  return s.replace(CYRILLIC_GREEK_PATTERN, (c) => HOMOGLYPH_MAP[c] ?? c);
}

/**
 * Steps 1-6 as one pass: the folded string still carries word separators and
 * digits — the form split (step 8) and repetition collapse (step 7) run per
 * form in matchVariants. Total over any input; every sub-step is a string
 * replace or `normalize`, none of which throw on lone surrogates.
 */
function foldCore(text: string): string {
  const nfkc = text.normalize('NFKC'); // 1
  const stripped = stripFormat(nfkc); // 2
  const arabic = foldArabic(stripped); // 3
  const digits = foldDigits(arabic); // 4
  const cased = turkishCasefold(digits); // 5
  return foldHomoglyphs(cased); // 6
}

/**
 * Step 9, exported SEPARATELY so matching can run against both the folded and
 * unfolded variants (the Arabizi-preserving requirement). Folds the leet table
 * over a string; 2/6/9 pass through unchanged.
 */
export function leetFold(s: string): string {
  return s.replace(LEET_PATTERN, (c) => LEET_MAP[c] ?? c);
}

/** Step 7: collapse every run of the SAME letter (≥2) to one; digits untouched. */
function collapseRepetition(s: string): string {
  return s.replace(REPETITION_PATTERN, '$1');
}

/**
 * Step 8 (space-collapsed form) + step 7: every maximal run of non-word
 * characters (anything but a Unicode letter or an ASCII digit) becomes a single
 * space; then repetition collapses. Digits survive as word characters so an
 * Arabizi "3ayez" keeps its 3 in this form (the leet variant handles the folded
 * reading separately).
 */
function spaceForm(folded: string): string {
  return collapseRepetition(folded.replace(/[^\p{L}0-9]+/gu, ' ').trim());
}

/**
 * Step 8 (separator-stripped form) + step 7: every non-LETTER is removed (digits
 * included), then repetition collapses. This is the form the injected-separator
 * evasion ("k-i-l-l") and the token-boundary rule read against.
 */
function stripForm(folded: string): string {
  return collapseRepetition(folded.replace(/[^\p{L}]/gu, ''));
}

/** Split a space-collapsed form into its words (empty string → no words). */
function splitWords(space: string): string[] {
  return space.length === 0 ? [] : space.split(' ');
}

/** The two normalized forms of a text (steps 1-8, unfolded). */
export interface NormalizedForms {
  spaceCollapsed: string;
  separatorStripped: string;
}

/**
 * The normalized forms of a text — the SAME function lexicon entries are compiled
 * through, so a seed and matching input can never fold differently. Applies
 * steps 1-8 (no leet); matchVariants layers the leet variant on top.
 */
export function normalize(text: string): NormalizedForms {
  const folded = foldCore(text);
  return { spaceCollapsed: spaceForm(folded), separatorStripped: stripForm(folded) };
}

/**
 * All four match variants of a text: {spaceCollapsed, separatorStripped} ×
 * {unfolded, leet-folded}, plus the word lists the token rule reads. Matching
 * over ALL of these is monotone — every extra variant only adds match surface,
 * so it can over-trigger but never miss (Decision 3). The leet variant is
 * produced from the folded string BEFORE the form split so the leet punctuation
 * (@/$/!) is still present to fold.
 */
export interface MatchVariants {
  spaceCollapsed: string;
  separatorStripped: string;
  leetSpaceCollapsed: string;
  leetSeparatorStripped: string;
  /** Words of `spaceCollapsed`, for the token maximal-word-run rule. */
  words: string[];
  /** Words of `leetSpaceCollapsed`. */
  leetWords: string[];
}

export function matchVariants(text: string): MatchVariants {
  const folded = foldCore(text);
  const leeted = leetFold(folded);
  const spaceCollapsed = spaceForm(folded);
  const separatorStripped = stripForm(folded);
  const leetSpaceCollapsed = spaceForm(leeted);
  const leetSeparatorStripped = stripForm(leeted);
  return {
    spaceCollapsed,
    separatorStripped,
    leetSpaceCollapsed,
    leetSeparatorStripped,
    words: splitWords(spaceCollapsed),
    leetWords: splitWords(leetSpaceCollapsed),
  };
}

/**
 * The token match rule (ADR-016 Decision 3 token mode): `token` (a normalized,
 * separator-stripped letter run) matches iff it equals a CONTIGUOUS concatenation
 * of whole words — every internal boundary of the concatenation was a real
 * separator (or a string edge) in the original text. This is the sound reading of
 * "a maximal letter-run whose boundaries correspond to non-letters in the
 * original":
 *   - "ö l" / "ö-l" → words ["o","l"] → "o"+"l" = "ol" HIT (the spacing evasion).
 *   - "göl" → words ["gol"] → no subsequence equals "ol" MISS (the false-positive
 *     guard: "ol" is a proper substring of the single real word "gol", never a
 *     word-boundary concatenation).
 * Returns false for an empty token (a degenerate lexicon entry never over-fires).
 */
export function tokenMatchesWords(words: readonly string[], token: string): boolean {
  if (token.length === 0) {
    return false;
  }
  for (let i = 0; i < words.length; i++) {
    let acc = '';
    for (let j = i; j < words.length; j++) {
      acc += words[j];
      if (acc.length > token.length) {
        break; // no shorter concatenation from i can still reach the token
      }
      if (acc === token) {
        return true;
      }
    }
  }
  return false;
}
