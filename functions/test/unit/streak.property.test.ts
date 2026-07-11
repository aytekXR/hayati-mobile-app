import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

import { localDayKey } from '../../src/rollover/day-key';
import {
  addDaysToDayKey,
  applyMutualDay,
  INITIAL_STREAK,
  isoWeekKey,
  type StreakState,
} from '../../src/streak/streak';

// M3.4 streak property tests — THE M3 accept line (docs/resume-prompt.md,
// docs/test-suite.md §1): "streak property tests: grace, gaps, timezone edges".
// applyMutualDay is pure Gregorian math over yyyymmdd dayKeys, so grace/gap/
// reset invariants are exhaustively fuzzable with no emulator; the timezone
// block feeds REAL localDayKey output (day-key.ts, Node ICU) through the engine
// to prove the two compose across DST — the only place a zone ever enters.

// A valid dayKey somewhere in 2020-01-01 .. ~2033-09 (5000 days out), built with
// the same helper under test so the arbitrary can never drift from real dates.
const dayKeyArb = fc.integer({ min: 0, max: 5000 }).map((k) => addDaysToDayKey('20200101', k));

// Reachable-shaped streak states: graceTokens is only ever {0, 1} in practice.
const streakStateArb: fc.Arbitrary<StreakState> = fc.record({
  count: fc.integer({ min: 0, max: 1000 }),
  lastMutualDate: fc.option(dayKeyArb, { nil: null }),
  graceTokens: fc.constantFrom(0, 1),
});

// Same, but always with a prior mutual day (non-null) — needed by the tests
// that step relative to lastMutualDate.
const datedStateArb: fc.Arbitrary<StreakState> = fc.record({
  count: fc.integer({ min: 0, max: 1000 }),
  lastMutualDate: dayKeyArb,
  graceTokens: fc.constantFrom(0, 1),
});

/** The dayKey of the ISO Monday that starts `dayKey`'s week. */
function isoMondayOf(dayKey: string): string {
  const y = Number(dayKey.slice(0, 4));
  const m = Number(dayKey.slice(4, 6));
  const d = Number(dayKey.slice(6, 8));
  const isoWeekday = new Date(Date.UTC(y, m - 1, d)).getUTCDay() || 7; // Mon=1..Sun=7
  return addDaysToDayKey(dayKey, -(isoWeekday - 1));
}

describe('applyMutualDay properties — grace, gaps, ordering', () => {
  it('a chain of consecutive days grows count by exactly its length, from any state', () => {
    fc.assert(
      fc.property(datedStateArb, fc.integer({ min: 1, max: 30 }), (start, n) => {
        const base = start.lastMutualDate as string;
        let cur = start;
        for (let i = 1; i <= n; i++) {
          cur = applyMutualDay(cur, addDaysToDayKey(base, i));
        }
        expect(cur.count).toBe(start.count + n);
        expect(cur.lastMutualDate).toBe(addDaysToDayKey(base, n));
      }),
    );
  });

  it('is same-day idempotent: applying the same dayKey twice equals applying it once', () => {
    fc.assert(
      fc.property(streakStateArb, dayKeyArb, (s, d) => {
        const once = applyMutualDay(s, d);
        expect(applyMutualDay(once, d)).toEqual(once);
      }),
    );
  });

  it('resets to 1 on any gap of two or more missed days, regardless of tokens', () => {
    fc.assert(
      // dayKey = last + k, k >= 3 → at least two missed days (last+1, last+2).
      fc.property(datedStateArb, fc.integer({ min: 3, max: 60 }), (s, k) => {
        const gapped = addDaysToDayKey(s.lastMutualDate as string, k);
        expect(applyMutualDay(s, gapped).count).toBe(1);
      }),
    );
  });

  it('bridges a one-day gap within a week iff a token is held; else resets', () => {
    fc.assert(
      fc.property(
        dayKeyArb,
        fc.integer({ min: 0, max: 3 }), // Mon..Thu offset keeps last+2 in the same week
        fc.integer({ min: 1, max: 500 }),
        fc.constantFrom(0, 1),
        (seed, offset, count, graceTokens) => {
          const last = addDaysToDayKey(isoMondayOf(seed), offset); // Mon..Thu
          const bridge = addDaysToDayKey(last, 2); // Wed..Sat — same ISO week, no refill
          fc.pre(isoWeekKey(bridge) === isoWeekKey(last));
          const res = applyMutualDay({ count, lastMutualDate: last, graceTokens }, bridge);
          if (graceTokens >= 1) {
            expect(res).toEqual({ count: count + 1, lastMutualDate: bridge, graceTokens: 0 });
          } else {
            expect(res).toEqual({ count: 1, lastMutualDate: bridge, graceTokens: 0 });
          }
        },
      ),
    );
  });

  it('refills weekly: a later-week bridge succeeds even entering with zero tokens', () => {
    fc.assert(
      fc.property(dayKeyArb, fc.integer({ min: 1, max: 500 }), (seed, count) => {
        const saturday = addDaysToDayKey(isoMondayOf(seed), 5); // Sat
        const bridge = addDaysToDayKey(saturday, 2); // Mon of the NEXT ISO week
        expect(isoWeekKey(bridge) > isoWeekKey(saturday)).toBe(true);
        // Enter with 0 tokens: the week-entry refill grants one, then the bridge
        // spends it → count grows, token back to 0.
        const res = applyMutualDay({ count, lastMutualDate: saturday, graceTokens: 0 }, bridge);
        expect(res).toEqual({ count: count + 1, lastMutualDate: bridge, graceTokens: 0 });
      }),
    );
  });

  it('leaves state untouched for any dayKey at or before lastMutualDate', () => {
    fc.assert(
      fc.property(datedStateArb, fc.integer({ min: 0, max: 60 }), (s, k) => {
        const older = addDaysToDayKey(s.lastMutualDate as string, -k);
        expect(applyMutualDay(s, older)).toBe(s); // same reference: provably unchanged
      }),
    );
  });

  it('never moves lastMutualDate backward over any sequence of dayKeys', () => {
    fc.assert(
      fc.property(streakStateArb, fc.array(dayKeyArb, { maxLength: 40 }), (s0, days) => {
        let cur = s0;
        let prevLast = s0.lastMutualDate;
        for (const d of days) {
          cur = applyMutualDay(cur, d);
          expect(cur.lastMutualDate).not.toBeNull();
          if (prevLast !== null) {
            expect((cur.lastMutualDate as string) >= prevLast).toBe(true);
          }
          prevLast = cur.lastMutualDate;
        }
      }),
    );
  });

  it('keeps graceTokens in {0,1} and count a non-negative integer, from INITIAL', () => {
    fc.assert(
      fc.property(fc.array(dayKeyArb, { maxLength: 60 }), (days) => {
        let cur = INITIAL_STREAK;
        for (const d of days) {
          cur = applyMutualDay(cur, d);
          expect(cur.graceTokens === 0 || cur.graceTokens === 1).toBe(true);
          expect(Number.isInteger(cur.count) && cur.count >= 0).toBe(true);
        }
      }),
    );
  });
});

// The parity fixture's zones (functions/test/fixtures/day-key-parity.json): a
// mix with DST (New_York, London, Auckland, Chatham) and without (Kathmandu,
// Riyadh, Istanbul), plus sub-hour offsets (Kathmandu +05:45, Chatham +12:45).
const PARITY_ZONES = [
  'America/New_York',
  'Asia/Kathmandu',
  'Asia/Riyadh',
  'Europe/Istanbul',
  'Europe/London',
  'Pacific/Auckland',
  'Pacific/Chatham',
] as const;

describe('timezone / DST edges — localDayKey feeds the streak with no skip or double', () => {
  for (const zone of PARITY_ZONES) {
    it(`${zone}: every consecutive 2026 local day increments the streak exactly once`, () => {
      // Walk all of 2026 hour by hour (crosses BOTH DST transitions for the DST
      // zones — spring's 23h day and autumn's 25h day — and every fixture
      // instant). A DST day is still sampled ≥23 times, so the hourly walk
      // visits every local calendar day at least once.
      const startMs = Date.UTC(2026, 0, 1, 0, 0, 0);
      const endMs = Date.UTC(2026, 11, 31, 23, 0, 0);
      const uniqueKeys: string[] = [];
      let previous: string | null = null;
      for (let t = startMs; t <= endMs; t += 3_600_000) {
        let key: string;
        try {
          key = localDayKey(new Date(t), zone);
        } catch (error) {
          throw new Error(
            `localDayKey threw for ${zone} — tzdata missing the zone? ` +
              `(node ${process.version}, ICU ${process.versions.icu ?? '?'}): ${String(error)}`,
          );
        }
        if (key !== previous) {
          uniqueKeys.push(key);
          previous = key;
        }
      }

      // Each distinct day is EXACTLY the next calendar day — a skipped day would
      // show as a +2 step, a doubled day (localDayKey going backward) would
      // break the chain. Neither is allowed to survive a DST transition.
      for (let i = 1; i < uniqueKeys.length; i++) {
        expect(uniqueKeys[i]).toBe(addDaysToDayKey(uniqueKeys[i - 1], 1));
      }
      expect(uniqueKeys.length).toBeGreaterThanOrEqual(365);

      // Answering each of those consecutive local days in order ⇒ streak count
      // equals the number of days: the engine and localDayKey compose cleanly
      // across DST, no arithmetic ever touching a timezone offset.
      let streak = INITIAL_STREAK;
      for (const key of uniqueKeys) {
        streak = applyMutualDay(streak, key);
      }
      expect(streak.count).toBe(uniqueKeys.length);
      expect(streak.lastMutualDate).toBe(uniqueKeys[uniqueKeys.length - 1]);
    });
  }
});
