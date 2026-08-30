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

// WARNING: script properties, NOT a hand-rolled character range.
//
// The first version of this used a literal Hebrew/Arabic character class, and it
// was broken in a way that reads as fine: the Hebrew point it contained is TWO
// codepoints (U+05D9 + U+05B4), so the class parsed as U+0590-U+08FF, a
// standalone U+05D9, and then **U+05B4-U+FDFF** — a 63,000-codepoint range that
// swallows Devanagari, Thai, Hiragana, Han and most of the BMP, and calls all of
// it RTL. A test whose direction predicate is wrong agrees with whatever it is
// shown. Found by the built-diff review, and the lesson is one this repo already
// paid for: do not hand-roll a Unicode range when the engine will name the
// property for you — ADR-053 made exactly that call for the app-side table,
// which is why that one is GENERATED.
const RTL_SCRIPTS =
  /[\p{Script=Arabic}\p{Script=Hebrew}\p{Script=Syriac}\p{Script=Thaana}\p{Script=Nko}\p{Script=Samaritan}\p{Script=Mandaic}\p{Script=Adlam}]/u;
const LTR_LETTERS = /[\p{Script=Latin}\p{Script=Greek}\p{Script=Cyrillic}]/u;

/** The first character of bidi class L or R, or undefined if there is none. */
function firstStrong(text: string): string | undefined {
  for (const ch of text) {
    if (RTL_SCRIPTS.test(ch) || LTR_LETTERS.test(ch)) return ch;
  }
  return undefined;
}

function isRtl(ch: string): boolean {
  return RTL_SCRIPTS.test(ch);
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
      // Improper nesting: N0 pairs only `()` here and leaves the `]` unmatched,
      // which measured jumps to the head of the line AND mirrors into a `[`.
      // The first implementation called all four matched and kept them.
      ['(A [B)]', '(A [B)'],
      // A matched pair may WRAP the whole name — and then the content inside it
      // is itself at the edge. Measured: `أجاب (Aylin Y.)` renders `(.Aylin Y)`.
      ['(Aylin Y.)', '(Aylin Y)'],
      // ...but a pair in the MIDDLE is at no edge and is left entirely alone.
      ['Aylin (Y.)', 'Aylin (Y.)'],
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

  // ADR-065 D3a/D3b/D3c. These are a SECURITY table, not a formatting one: the
  // input is a Firebase Auth `displayName`, which the OTHER member of the couple
  // sets through a client SDK with no server validation, and the output lands on
  // this person's lock screen. Every expectation below was measured against the
  // shipped function BEFORE the fix, where each one came back unchanged.
  describe('the untrusted-input rules — every language, not only RTL', () => {
    const NL = '\n';
    const RLO = '\u202E'; // RIGHT-TO-LEFT OVERRIDE — reverses what follows it
    const FSI = '\u2068'; // the isolates ADR-059 D3 promised never enter a payload
    const PDI = '\u2069';
    const ZWNJ = '\u200C'; // orthography in Persian/Urdu — MUST survive
    const ZWJ = '\u200D'; // joins emoji sequences — MUST survive
    const SOFT_HYPHEN = '\u00AD';
    const WORD_JOINER = '\u2060';
    const ANNO_ANCHOR = '\uFFF9'; // interlinear annotation: hides text behind text
    const MARK = '\u0301'; // COMBINING ACUTE ACCENT

    const cases: readonly [string, string, string | undefined][] = [
      // D3a — line-break injection. The whole reason this rule exists: without
      // it these two lines land on a lock screen under our app's name, in the
      // visual position a system message occupies.
      ['newline injection', `Aylin${NL}${NL}Security alert: verify at evil.example`,
        'Aylin Security alert: verify at evil.example'],
      // ...and a separator becomes a SPACE, never nothing. Deleting it welds
      // two words into one nobody typed (`AylinSecurity`).
      ['CRLF becomes one space', `Ay${NL}\rlin`, 'Ay lin'],
      ['tab becomes a space', 'Ay\tlin', 'Ay lin'],
      // D3a — explicit bidi controls. RLO mid-string reverses the REST of the
      // sentence; it survived in both languages before this rule.
      ['RLO mid-string', `Ay${RLO}lin`, 'Aylin'],
      ['RLO trailing', `Aylin${RLO}`, 'Aylin'],
      // This pair is ADR-059 D3's invariant, which until now had no mechanism.
      ['FSI/PDI', `Ay${FSI}lin${PDI}`, 'Aylin'],
      // Invisibles an enumeration of the twelve bidi controls would have missed.
      ['soft hyphen', `Ay${SOFT_HYPHEN}lin`, 'Aylin'],
      ['word joiner', `Ay${WORD_JOINER}lin`, 'Aylin'],
      ['interlinear annotation', `Ay${ANNO_ANCHOR}lin`, 'Aylin'],
      // The two deliberate exceptions. Stripping these damages a real name to
      // close an attack neither can carry.
      ['ZWNJ survives (Persian/Urdu orthography)', `محمد${ZWNJ}رضا`, `محمد${ZWNJ}رضا`],
      ['ZWJ survives (emoji sequence)', `A ${ZWJ}B`, `A ${ZWJ}B`],
      // Whitespace runs collapse, so a name cannot pad the copy off the screen.
      ['NBSP and ideographic space collapse', 'Ay \u00A0\u3000 lin', 'Ay lin'],
      // A name that is ONLY unsafe characters has nothing left to be a name.
      ['controls only', `${NL}\t${RLO}`, undefined],
      // D3b — a mark RUN is capped; a name is base-mark-base-mark, never this.
      ['zalgo run is capped, name survives', `A${MARK.repeat(200)}ylin`,
        `A${MARK.repeat(8)}ylin`],
      // ...and real orthography never reaches the cap, so it is untouched.
      ['José in NFD is untouched', `Jose${MARK}`, `Jose${MARK}`],
      ['pointed Hebrew is untouched', 'שָׁלוֹם', 'שָׁלוֹם'],
      ['Vietnamese decomposed is untouched', 'Nguyê\u0303n', 'Nguyê\u0303n'],
      ['Arabic tashkeel is untouched', 'مُحَمَّد', 'مُحَمَّد'],
      // D3c — over the cap, DEGRADE. Never truncate: a truncated name is one its
      // owner does not have, and the name-free copy is already correct.
      ['64 code points is accepted', 'A'.repeat(64), 'A'.repeat(64)],
      ['65 code points degrades', 'A'.repeat(65), undefined],
      ['500 code points degrades', 'A'.repeat(500), undefined],
      // The cap sits ABOVE the app's own input bound (nameCaptureMaxLength = 50),
      // so the server never silently discards a name the app invites.
      ['the app\'s own 50-character maximum is accepted', 'A'.repeat(50), 'A'.repeat(50)],
    ];

    for (const [label, input, expected] of cases) {
      for (const language of LANGUAGES) {
        it(`${language}: ${label}`, () => {
          expect(sanitizePushName(input, language)).toBe(expected);
        });
      }
    }

    // A floor on the INPUT (lesson 110): a table that shrank to nothing would
    // report the same clean zero as one that passed.
    it('the table covers every case in every language', () => {
      // Counted by the assertion itself, not by me: the first draft said 23
      // and the floor said 22 (lesson 133 — a count is a claim).
      expect(cases.length).toBe(22);
      expect(cases.length * LANGUAGES.length).toBe(66);
    });

    // The point of the whole table, asserted at the seam rather than inferred:
    // what the PORT would receive can no longer carry a line break or a control.
    it('no composed payload can carry a newline or a bidi control', () => {
      let examined = 0;
      for (const language of LANGUAGES) {
        const payload = composePush({
          kind: 'partnerAnswered',
          language,
          discreet: false,
          partnerName: `Aylin${NL}Security alert${RLO}${FSI}${PDI}`,
        });
        for (const text of [payload.title, payload.body]) {
          expect(text).not.toContain(NL);
          expect(text).not.toContain(RLO);
          expect(text).not.toContain(FSI);
          expect(text).not.toContain(PDI);
          examined += 1;
        }
      }
      expect(examined).toBe(LANGUAGES.length * 2);
    });

    it('an over-long name produces the byte-identical name-free payload', () => {
      for (const language of LANGUAGES) {
        const withName = composePush({
          kind: 'partnerAnswered',
          language,
          discreet: false,
          partnerName: 'A'.repeat(500),
        });
        const nameFree = composePush({ kind: 'partnerAnswered', language, discreet: false });
        expect(withName).toEqual(nameFree);
      }
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
