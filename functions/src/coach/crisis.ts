// Pure crisis detector for the M5.1 coach safety spine (ADR-016 Decisions 2/3).
// The safety spine's accept line: seeded crisis phrases in TR/AR/EN (+ Arabizi)
// route to the professional-help path, never to the persona. A total function
// over plain strings — no Firestore, no I/O, and it NEVER throws on any input
// (fuzzed in coach-crisis.property.test.ts), so the handler's fail-closed catch
// (Decision 2) is defense in depth, not the primary guarantee.
//
// Every lexicon entry from ALL THREE languages is compiled ONCE through the same
// normalizer the input runs through (normalize.ts), so the matcher and its data
// can never skew. The client-declared `language` NEVER selects the detection
// lexicon (a lied-about language must not bypass detection — Decision 2 blocking
// finding); it selects only the help-copy localization elsewhere.

import { ALL_CRISIS_SEEDS, CrisisCategory, CrisisSeed } from './crisis-lexicon';
import { MatchVariants, matchVariants, normalize, tokenMatchesWords } from './normalize';

/** A lexicon entry pre-normalized into the two forms matching reads against. */
interface CompiledSeed {
  category: CrisisCategory;
  matchMode: CrisisSeed['matchMode'];
  /** Space-collapsed normalized phrase (multi-word phrases keep their spaces). */
  spaceForm: string;
  /** Separator-stripped normalized phrase (one letter run; the token needle). */
  stripForm: string;
}

/**
 * Compile every seed ONCE at module load through the SAME normalizer as the
 * input. Seeds whose normalized forms are empty (a phrase of only separators —
 * never a real seed) are dropped so they cannot vacuously match every string.
 */
const COMPILED_SEEDS: readonly CompiledSeed[] = ALL_CRISIS_SEEDS.flatMap((seed) => {
  const forms = normalize(seed.phrase);
  if (forms.spaceCollapsed.length === 0 || forms.separatorStripped.length === 0) {
    return [];
  }
  return [
    {
      category: seed.category,
      matchMode: seed.matchMode,
      spaceForm: forms.spaceCollapsed,
      stripForm: forms.separatorStripped,
    },
  ];
});

/**
 * Does one compiled seed match one text's variants? Matching is over ALL four
 * variants (both forms × leet/unfolded), which is monotone: extra surface can
 * over-trigger but never miss.
 *   - `substring`: the space-collapsed needle in a space-collapsed haystack (real
 *     spacing) OR the separator-stripped needle in a stripped haystack (injected
 *     separators), across both leet variants.
 *   - `token`: the stripped needle equals a whole-word run (the maximal-word-run
 *     rule — keeps the false-positive control without reopening the spacing hole).
 */
function seedMatches(seed: CompiledSeed, v: MatchVariants): boolean {
  if (seed.matchMode === 'token') {
    return tokenMatchesWords(v.words, seed.stripForm) || tokenMatchesWords(v.leetWords, seed.stripForm);
  }
  return (
    v.spaceCollapsed.includes(seed.spaceForm) ||
    v.leetSpaceCollapsed.includes(seed.spaceForm) ||
    v.separatorStripped.includes(seed.stripForm) ||
    v.leetSeparatorStripped.includes(seed.stripForm)
  );
}

export type CrisisVerdict = { hit: false } | { hit: true; category: CrisisCategory };

/**
 * Scan a window of message texts for any seeded crisis phrase (ADR-016
 * Decision 2/3). Each text is scanned, PLUS the space-joined concatenation of the
 * whole window — a phrase split across two turns ("kill" / "myself") must still
 * hit. The FIRST matching seed's category is returned (both categories route to
 * the same help path; the category tunes only the help copy / log). Total: never
 * throws on any string input.
 */
export function detectCrisis(texts: readonly string[]): CrisisVerdict {
  // Each message individually + the whole-window concatenation (the cross-message
  // split guard). The handler truncates each message to 4,000 chars UPSTREAM
  // (truncateForScan) before calling; this core scans whatever it is given.
  const scans = texts.length > 0 ? [...texts, texts.join(' ')] : [''];
  const variants = scans.map(matchVariants);
  for (const seed of COMPILED_SEEDS) {
    for (const v of variants) {
      if (seedMatches(seed, v)) {
        return { hit: true, category: seed.category };
      }
    }
  }
  return { hit: false };
}
