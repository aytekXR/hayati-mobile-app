// Property tests for the coach crisis detector (ADR-016 Decision 3, test
// commitment 1): ONE mutation class per normalizer step applied to every seed
// phrase — removing any fold turns a class red — plus a total-function fuzz
// (detectCrisis never throws on arbitrary unicode). Seeds are imported from the
// lexicon, so the property suite and the shipped data can never drift.
import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

import { detectCrisis } from '../../src/coach/crisis';
import {
  CRISIS_LEXICON_AR,
  CRISIS_LEXICON_EN,
  CRISIS_LEXICON_TR,
  CrisisSeed,
} from '../../src/coach/crisis-lexicon';

// --- seed partitions --------------------------------------------------------
const isArabicScript = (s: string): boolean => /[؀-ۿ]/.test(s);
const AR_SCRIPT_SEEDS = CRISIS_LEXICON_AR.filter((s) => isArabicScript(s.phrase));
const ARABIZI_SEEDS = CRISIS_LEXICON_AR.filter((s) => !isArabicScript(s.phrase));
const TR_SEEDS = [...CRISIS_LEXICON_TR];
const EN_SEEDS = [...CRISIS_LEXICON_EN];
// Latin-script seeds that tolerate letter-level Latin mutations (separator /
// repetition / homoglyph). Arabizi included; leet is EN+TR only (leet-folding an
// Arabizi seed's OTHER letters can corrupt it — the ADR's exact concern).
const LATIN_SEEDS = [...TR_SEEDS, ...EN_SEEDS, ...ARABIZI_SEEDS];
const LEET_SEEDS = [...TR_SEEDS, ...EN_SEEDS];

// --- mutation helpers (each is total and guaranteed detectable) -------------
const HARAKAT = ['ً', 'ٌ', 'ٍ', 'َ', 'ُ', 'ِ', 'ّ', 'ْ'];
const TATWEEL = 'ـ';
const LEET_REV: Readonly<Record<string, string>> = { e: '3', i: '1', o: '0', a: '4', s: '5', t: '7', b: '8' };
const HOMOGLYPH_REV: Readonly<Record<string, string>> = {
  a: 'а', e: 'е', o: 'о', c: 'с', p: 'р', y: 'у', x: 'х', k: 'к', i: 'і',
};
const SEPARATORS = [' ', '-', '.', '_', '*'];

const isArabicLetter = (c: string): boolean => /[ء-ي]/.test(c);

/** Insert a harakat after every Arabic letter (stripped by step 3). */
function injectHarakat(phrase: string, markIdx: number): string {
  let out = '';
  for (const c of phrase) {
    out += c;
    if (isArabicLetter(c)) {
      out += HARAKAT[markIdx % HARAKAT.length];
    }
  }
  return out;
}

/** Insert n tatweels between adjacent Arabic letters (stripped by step 3). */
function injectTatweel(phrase: string, n: number): string {
  const chars = [...phrase];
  let out = '';
  for (let i = 0; i < chars.length; i++) {
    out += chars[i];
    if (isArabicLetter(chars[i]) && i + 1 < chars.length && isArabicLetter(chars[i + 1])) {
      out += TATWEEL.repeat(n);
    }
  }
  return out;
}

/** Diacritic-less Turkish typing (step 5's blocking case). */
function stripTurkishDiacritics(phrase: string): string {
  return phrase
    .replace(/ö/g, 'o')
    .replace(/ü/g, 'u')
    .replace(/ç/g, 'c')
    .replace(/ş/g, 's')
    .replace(/ğ/g, 'g')
    .replace(/ı/g, 'i')
    .replace(/İ/g, 'I');
}

function toTurkishUpper(c: string): string {
  if (c === 'i') return 'İ';
  if (c === 'ı') return 'I';
  return c.toUpperCase();
}
function toTurkishLower(c: string): string {
  if (c === 'I') return 'ı';
  if (c === 'İ') return 'i';
  return c.toLowerCase();
}

/** Randomize Turkish case, including the İ/ı family (step 5). */
function randomizeTurkishCase(phrase: string, flags: boolean[]): string {
  const chars = [...phrase];
  let out = '';
  for (let i = 0; i < chars.length; i++) {
    out += flags[i % flags.length] ? toTurkishUpper(chars[i]) : toTurkishLower(chars[i]);
  }
  return out;
}

/** Leet-substitute chosen Latin letters (step 9's leet variant). */
function leetSub(phrase: string, flags: boolean[]): string {
  let out = '';
  let k = 0;
  for (const c of phrase) {
    const low = c.toLowerCase();
    const rep = LEET_REV[low];
    if (rep !== undefined && flags[k++ % flags.length]) {
      out += rep;
    } else {
      out += c;
    }
  }
  return out;
}

/** Swap chosen Latin letters for a Cyrillic homoglyph (step 6). */
function homoglyphSwap(phrase: string, flags: boolean[]): string {
  let out = '';
  let k = 0;
  for (const c of phrase) {
    const low = c.toLowerCase();
    const rep = HOMOGLYPH_REV[low];
    if (rep !== undefined && flags[k++ % flags.length]) {
      out += rep;
    } else {
      out += c;
    }
  }
  return out;
}

/** Inject a separator between every pair of chars (step 8 separator-stripped). */
function injectSeparators(phrase: string, sepIdx: number): string {
  const sep = SEPARATORS[sepIdx % SEPARATORS.length];
  const chars = [...phrase];
  return chars.join(sep);
}

/** Inflate every letter to a run of 1+n (step 7 collapse). */
function inflateRepetition(phrase: string, n: number): string {
  let out = '';
  for (const c of phrase) {
    out += /\p{L}/u.test(c) ? c.repeat(1 + n) : c;
  }
  return out;
}

/** ASCII digits → Arabic-Indic (step 4). */
function arabicIndicDigits(phrase: string): string {
  return phrase.replace(/[0-9]/g, (d) => String.fromCodePoint(0x0660 + Number(d)));
}

/** Assert every seed in `seeds`, mutated by `mutate`, still detects. */
function expectAllDetected(seeds: readonly CrisisSeed[], mutate: (phrase: string) => string): void {
  for (const seed of seeds) {
    const mutated = mutate(seed.phrase);
    expect(detectCrisis([mutated]).hit, `missed after mutation: "${mutated}" (from "${seed.phrase}")`).toBe(true);
  }
}

const flagsArb = fc.array(fc.boolean(), { minLength: 1, maxLength: 8 });

describe('one mutation class per normalizer step — every seed still detects', () => {
  it('step 3: AR diacritic (harakat) insertion', () => {
    fc.assert(
      fc.property(fc.integer({ min: 0, max: 7 }), (markIdx) => {
        expectAllDetected(AR_SCRIPT_SEEDS, (p) => injectHarakat(p, markIdx));
      }),
    );
  });

  it('step 3: AR tatweel injection', () => {
    fc.assert(
      fc.property(fc.integer({ min: 1, max: 4 }), (n) => {
        expectAllDetected(AR_SCRIPT_SEEDS, (p) => injectTatweel(p, n));
      }),
    );
  });

  it('step 4: Arabic-Indic digit swap (Arabizi digit-letters)', () => {
    const withDigits = ARABIZI_SEEDS.filter((s) => /[0-9]/.test(s.phrase));
    expect(withDigits.length).toBeGreaterThan(0);
    expectAllDetected(withDigits, arabicIndicDigits);
  });

  it('step 5: TR diacritic stripping', () => {
    expectAllDetected(TR_SEEDS, stripTurkishDiacritics);
  });

  it('step 5: TR case randomization incl. İ/ı', () => {
    fc.assert(
      fc.property(flagsArb, (flags) => {
        expectAllDetected(TR_SEEDS, (p) => randomizeTurkishCase(p, flags));
      }),
    );
  });

  it('step 6: homoglyph substitution', () => {
    fc.assert(
      fc.property(flagsArb, (flags) => {
        expectAllDetected(LATIN_SEEDS, (p) => homoglyphSwap(p, flags));
      }),
    );
  });

  it('step 7: letter-repetition inflation', () => {
    fc.assert(
      fc.property(fc.integer({ min: 1, max: 4 }), (n) => {
        expectAllDetected([...LATIN_SEEDS, ...AR_SCRIPT_SEEDS], (p) => inflateRepetition(p, n));
      }),
    );
  });

  it('step 8: separator injection (including token entries)', () => {
    fc.assert(
      fc.property(fc.integer({ min: 0, max: 4 }), (sepIdx) => {
        expectAllDetected([...LATIN_SEEDS, ...AR_SCRIPT_SEEDS], (p) => injectSeparators(p, sepIdx));
      }),
    );
  });

  it('step 9: leet substitution (EN + TR)', () => {
    fc.assert(
      fc.property(flagsArb, (flags) => {
        expectAllDetected(LEET_SEEDS, (p) => leetSub(p, flags));
      }),
    );
  });

  it('cross-message split: a phrase split at any point still hits via concatenation', () => {
    const allSeeds = [...TR_SEEDS, ...EN_SEEDS, ...AR_SCRIPT_SEEDS, ...ARABIZI_SEEDS];
    fc.assert(
      fc.property(fc.constantFrom(...allSeeds), fc.integer({ min: 1, max: 40 }), (seed, cut) => {
        const chars = [...seed.phrase];
        if (chars.length < 2) {
          return; // single-char phrases have no interior split point
        }
        const k = 1 + (cut % (chars.length - 1));
        const a = chars.slice(0, k).join('');
        const b = chars.slice(k).join('');
        expect(detectCrisis([a, b]).hit, `missed split of "${seed.phrase}" at ${k}`).toBe(true);
      }),
    );
  });
});

describe('total-function fuzz — detectCrisis never throws', () => {
  it('on arbitrary unicode windows (incl. astral / lone surrogates)', () => {
    fc.assert(
      fc.property(fc.array(fc.string({ unit: 'binary' }), { maxLength: 6 }), (texts) => {
        expect(() => detectCrisis(texts)).not.toThrow();
      }),
      { numRuns: 500 },
    );
  });

  it('on the empty window and single empty string', () => {
    expect(() => detectCrisis([])).not.toThrow();
    expect(() => detectCrisis([''])).not.toThrow();
  });
});
