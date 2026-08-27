import { describe, expect, it } from 'vitest';

import { composePush, type PushKind, type PushLanguage } from '../../src/notifications/payload-policy';

// M3.4 (ADR-012 decision 3, PRD F6). composePush is pure copy policy over three
// axes: kind × recipient language × discreet. The tests below are a standing
// AUDIT of the whole copy surface — every combination must be non-empty, free of
// interpolation artifacts, and (in discreet mode) free of any event specific.
// The ABSOLUTE privacy invariant — no question/answer text in any payload — is
// enforced by the type signature (composePush has no such parameter) and
// re-asserted here as a guardrail on the API surface.

const KINDS: readonly PushKind[] = ['partnerAnswered', 'reveal', 'streakAtRisk', 'dailyQuestion'];
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

  // ADR-019 D3: the coupleEnded partner-notification is field + in-app notice
  // only — deliberately NO push, because it would deliver a proactive real-time
  // ping to a possibly-abusive partner at the deleting victim's moment of escape.
  //
  // THIS TEST CARRIES TWO DIFFERENT THINGS, and they are not equally negotiable.
  //   * `not.toContain('coupleEnded')` IS the ADR-019 safety invariant. It does
  //     not change when the vocabulary grows. Do not touch it.
  //   * the exact-union pin is a CHANGE DETECTOR. It is supposed to redden when a
  //     kind is added, so that a human reads the line above before proceeding.
  //
  // S063 added `dailyQuestion` (ADR-042 D3) and updated the detector to four,
  // deliberately, having read the invariant. A session that meets this red and
  // relaxes the test wholesale deletes a DV control while believing it fixed a
  // test (ADR-042 D5 names this exact hazard).
  it('the PushKind union is exactly the four shipped kinds, and no coupleEnded push exists (ADR-019 D3)', async () => {
    const { readFileSync } = await import('node:fs');
    const { fileURLToPath } = await import('node:url');
    const source = readFileSync(
      fileURLToPath(new URL('../../src/notifications/payload-policy.ts', import.meta.url)),
      'utf8',
    );
    expect(source).toContain(
      "export type PushKind = 'partnerAnswered' | 'reveal' | 'streakAtRisk' | 'dailyQuestion';",
    );
    // The invariant, not the detector.
    expect(source).not.toContain('coupleEnded');
    expect(KINDS).toHaveLength(4);
    expect([...KINDS].sort()).toEqual([
      'dailyQuestion',
      'partnerAnswered',
      'reveal',
      'streakAtRisk',
    ]);
  });

  // ADR-042 D3, hour re-pointed to 9 by ADR-045. The founder's first ask: "It
  // needs to be send new questions at 08.00 TSI with a question." The push
  // announces that a question EXISTS; the
  // question itself never travels — composePush has no question parameter, so
  // this is structural rather than a copy rule.
  describe('dailyQuestion (ADR-042 D3)', () => {
    it('is distinct copy in every language — not a reused streak or reveal body', () => {
      for (const language of LANGUAGES) {
        const daily = composePush({ kind: 'dailyQuestion', language, discreet: false });
        const atRisk = composePush({ kind: 'streakAtRisk', language, discreet: false, streakCount: 3 });
        const reveal = composePush({ kind: 'reveal', language, discreet: false });
        expectClean(daily);
        expect(daily.body).not.toBe(atRisk.body);
        expect(daily.body).not.toBe(reveal.body);
        expect(daily.title).not.toBe(atRisk.title);
      }
    });

    it('never claims the partner did anything — nobody has answered yet at 09:00', () => {
      for (const language of LANGUAGES) {
        const daily = composePush({
          kind: 'dailyQuestion',
          language,
          discreet: false,
          // A caller passing these must not be able to leak them into this kind.
          partnerName: 'Fahad',
          streakCount: 12,
        });
        expect(daily.title.includes('Fahad')).toBe(false);
        expect(daily.body.includes('Fahad')).toBe(false);
        expect(daily.body.includes('12')).toBe(false);
      }
    });

    it('is generic in discreet mode like every other kind', () => {
      for (const language of LANGUAGES) {
        const discreet = composePush({ kind: 'dailyQuestion', language, discreet: true });
        const otherDiscreet = composePush({ kind: 'reveal', language, discreet: true });
        expect(discreet).toEqual(otherDiscreet);
      }
    });
  });

  // ADR-042 D4 (hour 22 since ADR-045). The nudge fires for a couple with NO streak — that is the
  // whole point of dropping the streak gate. The count-free copy therefore may
  // not talk about a streak: "Your streak together is still alive" is FALSE for
  // the population this change exists to reach, and telling someone their streak
  // is alive when they have none is worse than saying nothing.
  describe('streakAtRisk with no streak — the relationship nudge (ADR-042 D4)', () => {
    it('never mentions a streak when there is no streak', () => {
      const streakWords = ['streak', 'seri', 'تتابع'];
      for (const language of LANGUAGES) {
        const noStreak = composePush({ kind: 'streakAtRisk', language, discreet: false });
        expectClean(noStreak);
        for (const word of streakWords) {
          expect(noStreak.title.toLowerCase().includes(word)).toBe(false);
          expect(noStreak.body.toLowerCase().includes(word)).toBe(false);
        }
      }
    });

    it('still uses the streak copy when a streak exists — nothing is lost', () => {
      for (const language of LANGUAGES) {
        const withStreak = composePush({
          kind: 'streakAtRisk',
          language,
          discreet: false,
          streakCount: 5,
        });
        expect(withStreak.body.includes('5')).toBe(true);
      }
    });

    it('a zero or negative count takes the no-streak copy, not a "0-day streak"', () => {
      for (const count of [0, -3]) {
        const payload = composePush({
          kind: 'streakAtRisk',
          language: 'en',
          discreet: false,
          streakCount: count,
        });
        expect(payload.body.includes(String(count))).toBe(false);
        expect(payload.body.toLowerCase().includes('streak')).toBe(false);
      }
    });
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
          // Deliberately a LITERAL, not an import of APP_NAME: asserting the
          // constant against itself would pass for any value, including one
          // that leaks what the app is for. ADR-012's discreet-title promise is
          // only guarded while this string is written out here. (S054: moved
          // Hayati -> ikimiz with the rename, ADR-035.)
          expect(composePush({ kind, language, discreet: true }).title).toBe('ikimiz');
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
