import { describe, expect, it } from 'vitest';

import { composePush, type PushKind, type PushLanguage } from '../../src/notifications/payload-policy';

// M3.4 (ADR-012 decision 3, PRD F6). composePush is pure copy policy over three
// axes: kind × recipient language × discreet. The tests below are a standing
// AUDIT of the whole copy surface — every combination must be non-empty, free of
// interpolation artifacts, and (in discreet mode) free of any event specific.
// The ABSOLUTE privacy invariant — no question/answer text in any payload — is
// enforced by the type signature (composePush has no such parameter) and
// re-asserted here as a guardrail on the API surface.

const KINDS: readonly PushKind[] = ['partnerAnswered', 'reveal', 'streakAtRisk'];
const LANGUAGES: readonly PushLanguage[] = ['tr', 'ar', 'en'];

// Placeholder artifacts that a template bug would leak into the copy.
const ARTIFACTS = ['undefined', 'null', 'NaN', '{', '}', '${'];

function expectClean(payload: { title: string; body: string }): void {
  expect(payload.title.trim().length).toBeGreaterThan(0);
  expect(payload.body.trim().length).toBeGreaterThan(0);
  for (const text of [payload.title, payload.body]) {
    for (const artifact of ARTIFACTS) {
      expect(text.includes(artifact)).toBe(false);
    }
  }
}

describe('composePush', () => {
  it('produces clean, non-empty copy for every kind × language × discreet combination', () => {
    for (const kind of KINDS) {
      for (const language of LANGUAGES) {
        for (const discreet of [false, true]) {
          expectClean(composePush({ kind, language, discreet, partnerName: 'Fahad', streakCount: 12 }));
        }
      }
    }
  });

  describe('discreet mode leaks nothing event-specific', () => {
    it('never contains the partner name, in any kind or language', () => {
      for (const kind of KINDS) {
        for (const language of LANGUAGES) {
          const payload = composePush({ kind, language, discreet: true, partnerName: 'Fahad', streakCount: 9 });
          expect(payload.title.includes('Fahad')).toBe(false);
          expect(payload.body.includes('Fahad')).toBe(false);
        }
      }
    });

    it('never contains a digit of the streak count, in any kind or language', () => {
      for (const kind of KINDS) {
        for (const language of LANGUAGES) {
          const payload = composePush({ kind, language, discreet: true, streakCount: 7 });
          // No digit at all in a discreet payload — the count cannot leak.
          expect(/\d/.test(payload.title)).toBe(false);
          expect(/\d/.test(payload.body)).toBe(false);
        }
      }
    });

    it('keeps the title to the neutral app name only', () => {
      for (const kind of KINDS) {
        for (const language of LANGUAGES) {
          expect(composePush({ kind, language, discreet: true }).title).toBe('Hayati');
        }
      }
    });

    it('ignores kind entirely — the same generic body for every event in a language', () => {
      for (const language of LANGUAGES) {
        const bodies = KINDS.map((kind) => composePush({ kind, language, discreet: true }).body);
        expect(new Set(bodies).size).toBe(1);
      }
    });
  });

  describe('normal-mode partnerAnswered', () => {
    it('names the partner when provided (subject position, arbitrary name)', () => {
      const payload = composePush({ kind: 'partnerAnswered', language: 'en', discreet: false, partnerName: 'Fahad' });
      expect(payload.title).toContain('Fahad');
      expect(payload.body).toContain('Fahad');
    });

    it('degrades to name-free copy when partnerName is absent, in every language', () => {
      for (const language of LANGUAGES) {
        const payload = composePush({ kind: 'partnerAnswered', language, discreet: false });
        expectClean(payload);
        expect(payload.body.includes('Fahad')).toBe(false);
      }
      // English name-free copy names the generic "partner".
      expect(
        composePush({ kind: 'partnerAnswered', language: 'en', discreet: false }).title.toLowerCase(),
      ).toContain('partner');
    });

    it('degrades when partnerName is blank/whitespace', () => {
      const payload = composePush({ kind: 'partnerAnswered', language: 'tr', discreet: false, partnerName: '   ' });
      expectClean(payload);
      // Whitespace name must not have been interpolated into the copy.
      expect(payload.title.startsWith(' ')).toBe(false);
    });
  });

  describe('normal-mode streakAtRisk', () => {
    it('interpolates the streak count when positive', () => {
      const payload = composePush({ kind: 'streakAtRisk', language: 'en', discreet: false, streakCount: 12 });
      expect(payload.body).toContain('12');
    });

    it('floors a fractional count rather than leaking a decimal', () => {
      const payload = composePush({ kind: 'streakAtRisk', language: 'en', discreet: false, streakCount: 12.9 });
      expect(payload.body).toContain('12');
      expect(payload.body).not.toContain('12.9');
    });

    it('degrades to a count-free variant when the count is absent or non-positive, in every language', () => {
      for (const language of LANGUAGES) {
        for (const streakCount of [undefined, 0, -3, Number.NaN]) {
          const payload = composePush({ kind: 'streakAtRisk', language, discreet: false, streakCount });
          expectClean(payload);
          expect(/\d/.test(payload.body)).toBe(false);
        }
      }
    });
  });

  it('reveal copy references the shared answer without any answer text (name-free)', () => {
    // reveal takes no partnerName influence and, by construction, no answer text —
    // the copy may point AT the answer ("read it together") but never quotes it.
    for (const language of LANGUAGES) {
      const withName = composePush({ kind: 'reveal', language, discreet: false, partnerName: 'Fahad' });
      const without = composePush({ kind: 'reveal', language, discreet: false });
      expect(withName).toEqual(without); // partnerName does not alter reveal copy
      expect(withName.title.includes('Fahad')).toBe(false);
    }
  });
});
