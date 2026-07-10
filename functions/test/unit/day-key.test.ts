import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

import { localDayKey } from '../../src/rollover/day-key';

// M3.2 (docs/resume-prompt.md): dayKey is the couple's LOCAL calendar date as
// yyyymmdd — the same shape the app's soloDayKey produces (solo_day.dart) and
// the id of couples/{cid}/days/{yyyymmdd}. A couple gets its new day at ITS
// local midnight, so the boundary instant in UTC moves with the zone's offset,
// including DST shifts. These tests pin the boundary on both sides for fixed
// zones, DST-shifting zones (spring forward + fall back), and sub-hour-offset
// zones (implementation-plan.md M3 accept line: "rollover unit tests across
// timezones incl. DST").

describe('localDayKey', () => {
  it('formats yyyymmdd with zero padding', () => {
    // 2026-01-05 09:00 UTC is 12:00 in Istanbul (+03) — single-digit month/day.
    expect(localDayKey(new Date('2026-01-05T09:00:00Z'), 'Europe/Istanbul')).toBe('20260105');
  });

  it('rolls the day at local midnight in a fixed-offset zone (Europe/Istanbul, +03)', () => {
    expect(localDayKey(new Date('2026-07-09T20:59:59Z'), 'Europe/Istanbul')).toBe('20260709');
    expect(localDayKey(new Date('2026-07-09T21:00:00Z'), 'Europe/Istanbul')).toBe('20260710');
  });

  it('rolls the day at local midnight in Asia/Riyadh (+03, no DST)', () => {
    expect(localDayKey(new Date('2026-07-09T20:59:59Z'), 'Asia/Riyadh')).toBe('20260709');
    expect(localDayKey(new Date('2026-07-09T21:00:00Z'), 'Asia/Riyadh')).toBe('20260710');
  });

  it('moves the UTC boundary across a spring-forward day (America/New_York, 2026-03-08)', () => {
    // Before the transition the boundary is 05:00Z (EST, -05)…
    expect(localDayKey(new Date('2026-03-08T04:59:59Z'), 'America/New_York')).toBe('20260307');
    expect(localDayKey(new Date('2026-03-08T05:00:00Z'), 'America/New_York')).toBe('20260308');
    // …and the very next midnight arrives after only 23 local hours, at 04:00Z (EDT, -04).
    expect(localDayKey(new Date('2026-03-09T03:59:59Z'), 'America/New_York')).toBe('20260308');
    expect(localDayKey(new Date('2026-03-09T04:00:00Z'), 'America/New_York')).toBe('20260309');
  });

  it('moves the UTC boundary across a fall-back day (Europe/London, 2026-10-25)', () => {
    // BST (+01) night before the transition: midnight is 23:00Z.
    expect(localDayKey(new Date('2026-10-24T22:59:59Z'), 'Europe/London')).toBe('20261024');
    expect(localDayKey(new Date('2026-10-24T23:00:00Z'), 'Europe/London')).toBe('20261025');
    // The 25-hour day ends back on GMT: the next midnight is 00:00Z.
    expect(localDayKey(new Date('2026-10-25T23:59:59Z'), 'Europe/London')).toBe('20261025');
    expect(localDayKey(new Date('2026-10-26T00:00:00Z'), 'Europe/London')).toBe('20261026');
  });

  it('handles sub-hour offsets (Asia/Kathmandu, +05:45)', () => {
    expect(localDayKey(new Date('2026-07-09T18:14:59Z'), 'Asia/Kathmandu')).toBe('20260709');
    expect(localDayKey(new Date('2026-07-09T18:15:00Z'), 'Asia/Kathmandu')).toBe('20260710');
  });

  it('handles sub-hour offsets with DST (Pacific/Chatham, +12:45 winter)', () => {
    // Southern-hemisphere July is standard time (+12:45): midnight is 11:15Z.
    expect(localDayKey(new Date('2026-07-09T11:14:59Z'), 'Pacific/Chatham')).toBe('20260709');
    expect(localDayKey(new Date('2026-07-09T11:15:00Z'), 'Pacific/Chatham')).toBe('20260710');
  });

  it('throws on a timezone id outside the IANA set', () => {
    // Couple timezones are allow-listed at join (resolveCoupleTimezone), so an
    // unknown id here is corrupt state — surface it loudly, never guess a date.
    expect(() => localDayKey(new Date('2026-07-09T12:00:00Z'), 'Not/AZone')).toThrow(RangeError);
  });

  it('property: always 8 digits, non-decreasing in time, and stepping by whole calendar days', () => {
    const zones = [
      'Europe/Istanbul',
      'Asia/Riyadh',
      'America/New_York',
      'Europe/London',
      'Asia/Kathmandu',
      'Pacific/Chatham',
      'Pacific/Auckland',
      'America/Santiago',
    ];
    fc.assert(
      fc.property(
        fc.integer({ min: Date.UTC(2025, 0, 1), max: Date.UTC(2030, 11, 31) }),
        fc.constantFrom(...zones),
        (epochMs, zone) => {
          const key = localDayKey(new Date(epochMs), zone);
          expect(key).toMatch(/^\d{8}$/);
          // One hour later the key either stays put or advances to the next
          // calendar date — never backwards, never a skip (DST days are 23/25h,
          // both > 1h, so an hourly step can cross at most one midnight).
          const next = localDayKey(new Date(epochMs + 3_600_000), zone);
          expect(next >= key).toBe(true);
          if (next !== key) {
            const toUtcDate = (k: string) =>
              Date.UTC(Number(k.slice(0, 4)), Number(k.slice(4, 6)) - 1, Number(k.slice(6, 8)));
            expect(toUtcDate(next) - toUtcDate(key)).toBe(86_400_000);
          }
        },
      ),
    );
  });
});
