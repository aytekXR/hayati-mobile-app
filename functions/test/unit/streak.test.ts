import { describe, expect, it } from 'vitest';

import {
  addDaysToDayKey,
  applyMutualDay,
  INITIAL_STREAK,
  isoWeekKey,
  parseStreak,
  parseStreakChecked,
  type StreakState,
} from '../../src/streak/streak';

// M3.4 streak engine (ADR-012 Decision 2, docs/prd.md F3). These are the
// example-based pins — concrete inputs → concrete outputs — that anchor the
// property tests in streak.property.test.ts (the M3 accept line). Everything
// here is pure calendar math over yyyymmdd dayKeys; no timezone, no emulator.

describe('INITIAL_STREAK', () => {
  it('is the zero state an absent streak field reads as', () => {
    expect(INITIAL_STREAK).toEqual({ count: 0, lastMutualDate: null, graceTokens: 1 });
  });
});

describe('addDaysToDayKey', () => {
  it('steps forward within a month', () => {
    expect(addDaysToDayKey('20260315', 0)).toBe('20260315');
    expect(addDaysToDayKey('20260131', 1)).toBe('20260201');
  });

  it('crosses a year boundary', () => {
    expect(addDaysToDayKey('20261231', 1)).toBe('20270101');
    expect(addDaysToDayKey('20260101', -1)).toBe('20251231');
    // 2026 is not a leap year: 365 days lands exactly on the next Jan 1.
    expect(addDaysToDayKey('20260101', 365)).toBe('20270101');
  });

  it('respects leap-year February', () => {
    expect(addDaysToDayKey('20200228', 1)).toBe('20200229'); // 2020 is a leap year
    expect(addDaysToDayKey('20200229', 1)).toBe('20200301');
    expect(addDaysToDayKey('20190228', 1)).toBe('20190301'); // 2019 is not
    expect(addDaysToDayKey('20260301', -1)).toBe('20260228'); // 2026 is not
  });

  it('throws loudly on a malformed dayKey, naming the input', () => {
    expect(() => addDaysToDayKey('2026011', 1)).toThrow(/2026011/); // 7 digits
    expect(() => addDaysToDayKey('20261301', 1)).toThrow(/20261301/); // month 13
    expect(() => addDaysToDayKey('20260230', 1)).toThrow(/20260230/); // Feb 30
    expect(() => addDaysToDayKey('abcdefgh', 1)).toThrow(/abcdefgh/);
  });

  it('throws on a non-integer day count', () => {
    expect(() => addDaysToDayKey('20260101', 1.5)).toThrow(/integer/);
  });
});

describe('isoWeekKey', () => {
  it('numbers weeks Monday-start within a year', () => {
    expect(isoWeekKey('20260101')).toBe('2026-W01'); // Thu, week 1
    expect(isoWeekKey('20260709')).toBe('2026-W28');
  });

  it('uses the ISO week-NUMBERING year at the year boundary', () => {
    // 2027-01-01 is a Friday — still inside 2026's final week (W53), NOT 2027.
    expect(isoWeekKey('20270101')).toBe('2026-W53');
    expect(isoWeekKey('20261228')).toBe('2026-W53'); // Mon: start of that week
    expect(isoWeekKey('20270103')).toBe('2026-W53'); // Sun: end of that week
    expect(isoWeekKey('20270104')).toBe('2027-W01'); // Mon: first week of 2027
    // The mirror case: a late-December date whose week belongs to the next year.
    expect(isoWeekKey('20251229')).toBe('2026-W01');
    expect(isoWeekKey('20241231')).toBe('2025-W01');
  });

  it('compares lexicographically = chronologically across the week-year jump', () => {
    // The refill test in applyMutualDay depends on this ordering property.
    expect(isoWeekKey('20270105') > isoWeekKey('20270103')).toBe(true); // W01 > W53
    expect(isoWeekKey('20260105') > isoWeekKey('20260101')).toBe(true); // W02 > W01
  });

  it('throws on a malformed dayKey', () => {
    expect(() => isoWeekKey('20260000')).toThrow(/20260000/); // day 00
    expect(() => isoWeekKey('nope')).toThrow(/nope/);
  });
});

describe('parseStreakChecked', () => {
  it('reads an absent field as the zero state, not corruption', () => {
    expect(parseStreakChecked(undefined)).toEqual({ state: INITIAL_STREAK, corrupt: false });
  });

  it('passes through a structurally valid state', () => {
    const raw = { count: 5, lastMutualDate: '20260709', graceTokens: 0 };
    expect(parseStreakChecked(raw)).toEqual({ state: raw, corrupt: false });
  });

  it('accepts the null-date / any-non-negative-graceTokens states', () => {
    expect(parseStreakChecked({ count: 0, lastMutualDate: null, graceTokens: 1 }).corrupt).toBe(
      false,
    );
    // graceTokens > 1 is NOT corruption — the engine is robust to any budget, so
    // a future multi-token policy must not read as a bug.
    const many = parseStreakChecked({ count: 2, lastMutualDate: '20260101', graceTokens: 3 });
    expect(many.corrupt).toBe(false);
    expect(many.state.graceTokens).toBe(3);
  });

  it('flags every malformed shape as corrupt and falls back to the zero state', () => {
    const corruptInputs: unknown[] = [
      'nope', // wrong root type
      5,
      [],
      null, // an explicit null is a poke, not the absent zero state
      { count: -1, lastMutualDate: null, graceTokens: 1 }, // negative count
      { count: 1.5, lastMutualDate: null, graceTokens: 1 }, // non-integer count
      { count: 1, lastMutualDate: null, graceTokens: -1 }, // negative tokens
      { count: 1, lastMutualDate: '2026', graceTokens: 1 }, // bad dayKey string
      { count: 1, lastMutualDate: '20260230', graceTokens: 1 }, // impossible date
      { count: 1, lastMutualDate: 20260101, graceTokens: 1 }, // dayKey not a string
      { count: 1, graceTokens: 1 }, // missing lastMutualDate
      { lastMutualDate: null, graceTokens: 1 }, // missing count
      { count: 1, lastMutualDate: null, graceTokens: 1, extra: true }, // unknown key
    ];
    for (const raw of corruptInputs) {
      expect(parseStreakChecked(raw), `expected corrupt for ${JSON.stringify(raw)}`).toEqual({
        state: INITIAL_STREAK,
        corrupt: true,
      });
    }
  });
});

describe('parseStreak (pure form)', () => {
  it('returns just the state', () => {
    expect(parseStreak(undefined)).toEqual(INITIAL_STREAK);
    expect(parseStreak('junk')).toEqual(INITIAL_STREAK);
    expect(parseStreak({ count: 4, lastMutualDate: '20260101', graceTokens: 1 })).toEqual({
      count: 4,
      lastMutualDate: '20260101',
      graceTokens: 1,
    });
  });
});

describe('applyMutualDay — the seven decision branches', () => {
  it('first mutual day ever sets count 1 and keeps the token', () => {
    expect(applyMutualDay(INITIAL_STREAK, '20260101')).toEqual({
      count: 1,
      lastMutualDate: '20260101',
      graceTokens: 1,
    });
  });

  it('a consecutive day increments without spending a token', () => {
    const prev: StreakState = { count: 1, lastMutualDate: '20260101', graceTokens: 1 };
    expect(applyMutualDay(prev, '20260102')).toEqual({
      count: 2,
      lastMutualDate: '20260102',
      graceTokens: 1,
    });
  });

  it('the same day is a no-op returning the unchanged state', () => {
    const prev: StreakState = { count: 3, lastMutualDate: '20260101', graceTokens: 1 };
    expect(applyMutualDay(prev, '20260101')).toBe(prev);
  });

  it('an older day never rewrites history (returns the unchanged state)', () => {
    const prev: StreakState = { count: 5, lastMutualDate: '20260101', graceTokens: 1 };
    expect(applyMutualDay(prev, '20251231')).toBe(prev);
  });

  it('a gap of two or more missed days resets to 1', () => {
    // 20260104 is last + 3 (Jan 2 & 3 missed); same ISO week (W01), so no refill
    // muddies the token — count resets, token untouched.
    const prev: StreakState = { count: 5, lastMutualDate: '20260101', graceTokens: 1 };
    expect(applyMutualDay(prev, '20260104')).toEqual({
      count: 1,
      lastMutualDate: '20260104',
      graceTokens: 1,
    });
  });

  it('bridges exactly one missed day when a token is in hand, consuming it', () => {
    // 20260105 & 20260107 are both ISO week W02, so the refill does not apply;
    // the token that bridges is genuinely the one already held.
    const prev: StreakState = { count: 3, lastMutualDate: '20260105', graceTokens: 1 };
    expect(applyMutualDay(prev, '20260107')).toEqual({
      count: 4,
      lastMutualDate: '20260107',
      graceTokens: 0,
    });
  });

  it('resets on a one-day gap with no token (same ISO week as consumption)', () => {
    const prev: StreakState = { count: 3, lastMutualDate: '20260105', graceTokens: 0 };
    expect(applyMutualDay(prev, '20260107')).toEqual({
      count: 1,
      lastMutualDate: '20260107',
      graceTokens: 0,
    });
  });
});

describe('applyMutualDay — weekly refill across the ISO week-year boundary', () => {
  it('consumes a token in W53, fails a second bridge in W53, then a later-week bridge refills', () => {
    // A concrete year-boundary walk that exercises the ISO week-NUMBERING year:
    // 2026-W53 spans Mon 2026-12-28 .. Sun 2027-01-03 (yes, into January).
    const day = (s: StreakState, k: string) => applyMutualDay(s, k);

    const s1 = day(INITIAL_STREAK, '20261230'); // Wed W53: first mutual day
    expect(s1).toEqual({ count: 1, lastMutualDate: '20261230', graceTokens: 1 });

    // +2 days (one missed) and STILL W53 — the year rolled but not the ISO week.
    const s2 = day(s1, '20270101'); // Fri, 2026-W53
    expect(s2).toEqual({ count: 2, lastMutualDate: '20270101', graceTokens: 0 });

    // Another one-day gap, still W53, no token left → the mercy budget is spent.
    const s3 = day(s2, '20270103'); // Sun, 2026-W53
    expect(s3).toEqual({ count: 1, lastMutualDate: '20270103', graceTokens: 0 });

    // Now the ISO week advances to 2027-W01 → the token refills BEFORE this day
    // spends it, so the one-day gap bridges even though we entered with 0.
    const s4 = day(s3, '20270105'); // Tue, 2027-W01
    expect(s4).toEqual({ count: 2, lastMutualDate: '20270105', graceTokens: 0 });
  });
});
