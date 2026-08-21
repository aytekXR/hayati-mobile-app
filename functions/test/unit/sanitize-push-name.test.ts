import { describe, expect, it } from 'vitest';

import { sanitizePushName } from '../../src/notifications/sanitize-push-name';
import { composePush, type PushKind, type PushLanguage } from '../../src/notifications/payload-policy';

// ADR-059, issue #136. Two things are pinned here and they are different in kind:
//
//  1. `sanitizePushName`'s contract BY VALUE. A behavioural test of a trimming
//     rule cannot see WHICH characters it trims (lesson 117) — "call it and
//     assert the render is fine" passes for a rule that strips far too much, and
//     the cost of stripping too much is a person's name.
//  2. The INVARIANT the FriBidi measurement established: the first STRONG
//     character of a composed string must come from the copy, never from the
//     name. That is what decides paragraph direction (UAX #9 P2/P3), and it is
//     the property Decision 1's reordering exists to guarantee.

const KINDS: readonly PushKind[] = ['partnerAnswered', 'reveal', 'streakAtRisk', 'dailyQuestion'];
const LANGUAGES: readonly PushLanguage[] = ['tr', 'ar', 'en'];

// A name that is unambiguously RTL, so a string that lets the NAME choose the
// paragraph direction is detectable: its first strong character would be R.
const RTL_NAME = 'أيلين';

/** The first character of bidi class L or R, or undefined if there is none. */
function firstStrong(text: string): string | undefined {
  for (const ch of text) {
    // Arabic + Hebrew blocks stand in for R; the Latin/Turkish repertoire for L.
    if (/[֐-ࣿיִ-﷿ﹰ-﻿]/u.test(ch)) return ch;
    if (/\p{Script=Latin}/u.test(ch)) return ch;
  }
  return undefined;
}

function isRtl(ch: string): boolean {
  return /[֐-ࣿיִ-﷿ﹰ-﻿]/u.test(ch);
}

describe('sanitizePushName', () => {
  describe('the RTL copy — trailing neutrals detach, so they go', () => {
    // Every expectation here is the measured FriBidi outcome, not a guess.
    const cases: readonly [string, string | undefined][] = [
      ['Aylin', 'Aylin'],
      ['Aylin Y.', 'Aylin Y'],
      ['Aylin!', 'Aylin'],
      ['Aylin?', 'Aylin'],
      ['Aylin…', 'Aylin'],
      ['.Aylin', 'Aylin'],
      ['  Aylin  ', 'Aylin'],
      // A MATCHED pair survives: Unicode N0/BD16 resolves it to the enclosed
      // text, so `Ayşe (Y)` renders correctly and stripping it is pure damage.
      ['Ayşe (Y)', 'Ayşe (Y)'],
      // An UNMATCHED bracket is an ordinary neutral. Measured: `أجاب Aylin (`
      // renders `) Aylin ﺏﺎﺟﺃ` — it jumps AND mirrors.
      ['Aylin (', 'Aylin'],
      ['Aylin)', 'Aylin'],
      ['Sarah :)', 'Sarah'],
      // Digits are WEAK, not neutral, and are measured harmless. A rule written
      // as "neutral or weak" would eat them — ADR-059 rev 1 said exactly that.
      ['Aylin 2', 'Aylin 2'],
      ['Aylin 2.', 'Aylin 2'],
      // Nothing directional left -> undefined -> the caller's name-free copy.
      ['...', undefined],
      ['!!!', undefined],
      ['()', undefined],
      ['   ', undefined],
      ['', undefined],
      // An RTL name is untouched; the rule is about the EDGE, not the script.
      [RTL_NAME, RTL_NAME],
    ];

    for (const [input, expected] of cases) {
      it(`ar: ${JSON.stringify(input)} -> ${JSON.stringify(expected)}`, () => {
        expect(sanitizePushName(input, 'ar')).toBe(expected);
      });
    }

    it('undefined in, undefined out', () => {
      expect(sanitizePushName(undefined, 'ar')).toBeUndefined();
    });
  });

  describe('the LTR copy — nothing is trimmed, because nothing detaches', () => {
    // Measured: `Aylin Y. answered today's question.` is byte-identical
    // logical-to-visual. Trimming here would remove a character from someone's
    // name for no rendering benefit at all.
    for (const language of ['en', 'tr'] as const) {
      it(`${language} keeps a trailing neutral`, () => {
        expect(sanitizePushName('Aylin Y.', language)).toBe('Aylin Y.');
        expect(sanitizePushName('Sarah :)', language)).toBe('Sarah :)');
      });

      it(`${language} still trims surrounding whitespace and degrades on blank`, () => {
        expect(sanitizePushName('  Aylin  ', language)).toBe('Aylin');
        expect(sanitizePushName('   ', language)).toBeUndefined();
      });
    }
  });
});

describe('the paragraph direction is never the name to choose (ADR-059 D1)', () => {
  it('no composed string takes its first STRONG character from the name', () => {
    let examined = 0;
    for (const kind of KINDS) {
      for (const language of LANGUAGES) {
        const payload = composePush({
          kind,
          language,
          discreet: false,
          partnerName: RTL_NAME,
          streakCount: 12,
        });
        for (const text of [payload.title, payload.body]) {
          const strong = firstStrong(text);
          expect(strong, `no strong character at all in ${kind}/${language}`).toBeDefined();
          // Arabic copy is RTL-first; Turkish and English copy is Latin-first.
          // Either way the FIRST strong character must be the copy's, so an
          // RTL name cannot flip an LTR paragraph (or vice versa).
          expect(
            isRtl(strong as string),
            `${kind}/${language} lets the NAME choose the paragraph direction: ${JSON.stringify(text)}`,
          ).toBe(language === 'ar');
          examined += 1;
        }
      }
    }
    // A floor on the INPUT (lesson 110): a sweep whose loop matched nothing
    // reports the same clean zero as a sweep that passed.
    expect(examined).toBe(KINDS.length * LANGUAGES.length * 2);
  });

  it('holds in discreet mode too, where no name is interpolated at all', () => {
    for (const language of LANGUAGES) {
      const payload = composePush({
        kind: 'partnerAnswered',
        language,
        discreet: true,
        partnerName: RTL_NAME,
      });
      expect(payload.title.includes(RTL_NAME)).toBe(false);
      expect(payload.body.includes(RTL_NAME)).toBe(false);
    }
  });
});

describe('composePush routes a name-less name to the existing name-free copy', () => {
  it('an all-punctuation name produces the byte-identical name-free payload', () => {
    for (const language of LANGUAGES) {
      const sanitised = composePush({
        kind: 'partnerAnswered',
        language,
        discreet: false,
        partnerName: '...',
      });
      const nameFree = composePush({ kind: 'partnerAnswered', language, discreet: false });
      // Byte-identical, not merely "also clean": the fallback must be REACHED,
      // not just available.
      expect(sanitised).toEqual(nameFree);
    }
  });

  it('an Arabic-copy name loses its trailing neutral, and the copy still names it', () => {
    const payload = composePush({
      kind: 'partnerAnswered',
      language: 'ar',
      discreet: false,
      partnerName: 'Aylin Y.',
    });
    expect(payload.title).toContain('Aylin Y');
    expect(payload.title).not.toContain('Aylin Y.');
  });
});
