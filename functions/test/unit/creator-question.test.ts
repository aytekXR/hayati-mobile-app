// Pure unit tests for the partner-preview question hook core (PRD F1
// restore; redesign ui-ux §5.3) — no emulator required. The Firestore-reading
// wrapper (resolveCreatorQuestionHook) is exercised end-to-end by the
// emulator suite (test/emulator/invite-preview.test.ts); everything decidable
// lives here in `creatorQuestionHook` and its date helpers.
import { describe, expect, it } from 'vitest';

import {
  SOLO_QUESTION_DAYS,
  creatorQuestionHook,
  soloDayNumberUtc,
  todayWindowKeys,
  utcDayKey,
} from '../../src/invites/creator-question';
import type { QuestionPack } from '../../src/rollover/pack-loader';

/** A 7-question pack in the bundled solo shape. */
const pack: QuestionPack = {
  packId: 'solo_en',
  version: 1,
  locale: 'en',
  register: 'neutral',
  questions: Array.from({ length: SOLO_QUESTION_DAYS }, (_, i) => ({
    id: `solo_en_00${i + 1}`,
    category: 'gratitude' as const,
    depth: 1,
    text: `EN solo question ${i + 1}`,
    seasonalWindow: undefined,
  })),
};

const now = new Date('2026-07-25T12:00:00Z');

describe('utcDayKey', () => {
  it('formats the UTC calendar date as yyyymmdd (the soloDayKey shape)', () => {
    expect(utcDayKey(now)).toBe('20260725');
    expect(utcDayKey(new Date('2026-01-02T00:00:00Z'))).toBe('20260102');
  });
});

describe('soloDayNumberUtc (the app soloDayNumber mirror)', () => {
  it('is day 1 on the anchor date, day N on the Nth calendar date', () => {
    expect(soloDayNumberUtc(new Date('2026-07-25T01:00:00Z'), now)).toBe(1);
    expect(soloDayNumberUtc(new Date('2026-07-23T23:59:00Z'), now)).toBe(3);
  });

  it('counts calendar dates, not 24h intervals (created 23:59 → day 2 a '
    + 'minute later)', () => {
    expect(
      soloDayNumberUtc(
        new Date('2026-07-24T23:59:00Z'),
        new Date('2026-07-25T00:01:00Z'),
      ),
    ).toBe(2);
  });

  it('clamps a missing or future anchor to day 1 (the honest floor)', () => {
    expect(soloDayNumberUtc(undefined, now)).toBe(1);
    expect(soloDayNumberUtc(new Date('2026-08-01T00:00:00Z'), now)).toBe(1);
  });
});

describe('todayWindowKeys', () => {
  it('covers exactly yesterday/today/tomorrow in UTC (every real timezone)', () => {
    expect([...todayWindowKeys(now)].sort()).toEqual([
      '20260724',
      '20260725',
      '20260726',
    ]);
  });
});

describe('creatorQuestionHook', () => {
  const base = {
    contentLanguage: 'en',
    createdAt: new Date('2026-07-23T09:00:00Z'), // day 3 at `now`
    latestAnswer: undefined,
    pack,
    now,
  };

  it('a latest answer inside the today window returns ITS question with '
    + 'creatorAnswered: true (the PRD F1 line, keyed by what they answered)', () => {
    expect(
      creatorQuestionHook({
        ...base,
        latestAnswer: { dayKey: '20260725', questionId: 'solo_en_003' },
      }),
    ).toEqual({ questionText: 'EN solo question 3', creatorAnswered: true });
  });

  it('the window tolerates the unknown timezone by ±1 UTC day', () => {
    for (const dayKey of ['20260724', '20260726']) {
      expect(
        creatorQuestionHook({
          ...base,
          latestAnswer: { dayKey, questionId: 'solo_en_003' },
        }),
      ).toEqual({ questionText: 'EN solo question 3', creatorAnswered: true });
    }
  });

  it('an OLD latest answer falls back to the day-N question, unanswered', () => {
    expect(
      creatorQuestionHook({
        ...base,
        latestAnswer: { dayKey: '20260701', questionId: 'solo_en_001' },
      }),
    ).toEqual({ questionText: 'EN solo question 3', creatorAnswered: false });
  });

  it('no answers at all → the day-N question, unanswered', () => {
    expect(creatorQuestionHook(base)).toEqual({
      questionText: 'EN solo question 3',
      creatorAnswered: false,
    });
  });

  it('a today-answer whose questionId is not in the pack NEVER claims '
    + 'answered — it falls back to day-N unanswered', () => {
    expect(
      creatorQuestionHook({
        ...base,
        latestAnswer: { dayKey: '20260725', questionId: 'solo_tr_003' },
      }),
    ).toEqual({ questionText: 'EN solo question 3', creatorAnswered: false });
  });

  it('a missing createdAt clamps to day 1 (the pending-server-stamp window)', () => {
    expect(creatorQuestionHook({ ...base, createdAt: undefined })).toEqual({
      questionText: 'EN solo question 1',
      creatorAnswered: false,
    });
  });

  it('day 8+ with no today-answer → no hook (the solo cycle is complete; '
    + 'no honest "today\'s question" exists)', () => {
    expect(
      creatorQuestionHook({
        ...base,
        createdAt: new Date('2026-07-10T00:00:00Z'),
      }),
    ).toBeUndefined();
  });

  it('day 8+ but answered today → still the answered hook (the strongest '
    + 'honest form wins)', () => {
    expect(
      creatorQuestionHook({
        ...base,
        createdAt: new Date('2026-07-10T00:00:00Z'),
        latestAnswer: { dayKey: '20260725', questionId: 'solo_en_007' },
      }),
    ).toEqual({ questionText: 'EN solo question 7', creatorAnswered: true });
  });

  it('an off-vocabulary contentLanguage yields no hook (fail-soft)', () => {
    for (const contentLanguage of [undefined, null, 42, 'fr', '']) {
      expect(
        creatorQuestionHook({ ...base, contentLanguage }),
      ).toBeUndefined();
    }
  });
});
