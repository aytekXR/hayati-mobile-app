import { afterEach, describe, expect, it, vi } from 'vitest';

import { isQuietLocalHour, localHour } from '../../src/notifications/local-hour';

// M3.4 (ADR-012 decision 3). localHour is the sibling of localDayKey — same
// instant→zone projection through Intl, same formatter-cache and invalid-zone
// discipline — but it yields the 0..23 wall-clock hour that the quiet-hours
// policy and the hour-20 streak-at-risk sweep key off. The projection must be
// DST-correct (the boundary instant moves with the zone's offset) and must pin
// local midnight to 0 (never 24), including at the sub-hour offsets whose local
// midnight lands on a :15/:45 UTC instant.

describe('localHour', () => {
  it('reads the wall-clock hour in a fixed-offset zone (Europe/Istanbul, +03)', () => {
    // 12:00 UTC is 15:00 in Istanbul.
    expect(localHour(new Date('2026-07-09T12:00:00Z'), 'Europe/Istanbul')).toBe(15);
  });

  it('pins local midnight to 0, never 24 (h23), in a whole-hour zone', () => {
    // Istanbul +03: 21:00Z is exactly local midnight → 0.
    expect(localHour(new Date('2026-07-09T21:00:00Z'), 'Europe/Istanbul')).toBe(0);
    // One second before is the last hour of the previous day → 23.
    expect(localHour(new Date('2026-07-09T20:59:59Z'), 'Europe/Istanbul')).toBe(23);
  });

  it('moves the hour with the offset across a spring-forward transition (America/New_York)', () => {
    // 2026-03-08: at 07:00Z clocks jump 02:00 EST → 03:00 EDT. So 06:59:59Z is
    // local 01:59 (hour 1) and 07:00:00Z is local 03:00 (hour 3) — hour 2 never
    // exists that day, and no hour arithmetic here has to know that.
    expect(localHour(new Date('2026-03-08T06:59:59Z'), 'America/New_York')).toBe(1);
    expect(localHour(new Date('2026-03-08T07:00:00Z'), 'America/New_York')).toBe(3);
  });

  it('reflects DST vs standard offset across the year (Europe/London)', () => {
    // July is BST (+01): 12:00Z → 13. January is GMT (+00): 12:00Z → 12.
    expect(localHour(new Date('2026-07-01T12:00:00Z'), 'Europe/London')).toBe(13);
    expect(localHour(new Date('2026-01-01T12:00:00Z'), 'Europe/London')).toBe(12);
  });

  it('repeats the wall-clock hour across a fall-back transition (Europe/London)', () => {
    // 2026-10-25 01:00Z clocks fall 02:00 BST → 01:00 GMT, so local hour 1
    // happens twice; both instants read 1 with no ambiguity in the number.
    expect(localHour(new Date('2026-10-25T00:30:00Z'), 'Europe/London')).toBe(1); // 01:30 BST
    expect(localHour(new Date('2026-10-25T01:30:00Z'), 'Europe/London')).toBe(1); // 01:30 GMT
  });

  it('pins midnight to 0 at a +05:45 sub-hour offset (Asia/Kathmandu)', () => {
    // Local midnight is 18:15Z (+05:45). h23 must read that as 0, not 24…
    expect(localHour(new Date('2026-07-09T18:15:00Z'), 'Asia/Kathmandu')).toBe(0);
    // …and one second earlier is 23:59:59 local → 23.
    expect(localHour(new Date('2026-07-09T18:14:59Z'), 'Asia/Kathmandu')).toBe(23);
  });

  it('pins midnight to 0 at a +12:45 sub-hour offset (Pacific/Chatham, winter)', () => {
    // Southern-hemisphere July is standard time (+12:45): local midnight is 11:15Z.
    expect(localHour(new Date('2026-07-09T11:15:00Z'), 'Pacific/Chatham')).toBe(0);
    expect(localHour(new Date('2026-07-09T11:14:59Z'), 'Pacific/Chatham')).toBe(23);
  });

  it('throws RangeError on a timezone id outside the IANA set', () => {
    // Couple timezones are allow-listed at join (resolveCoupleTimezone), so an
    // unknown id here is corrupt state — surface it, never guess an hour.
    expect(() => localHour(new Date('2026-07-09T12:00:00Z'), 'Not/AZone')).toThrow(RangeError);
  });

  it('constructs one formatter per zone and reuses it across calls (cache)', () => {
    // Use a zone touched nowhere else in this file so the spy sees its FIRST
    // construction: the second call for the same zone must reuse the cached
    // formatter, i.e. exactly one construction for two calls. The mock delegates
    // to the real constructor so formatToParts still works — we count `new`s.
    const zone = 'America/Argentina/Buenos_Aires';
    const Original = Intl.DateTimeFormat;
    const spy = vi.spyOn(Intl, 'DateTimeFormat').mockImplementation(function (
      ...args: ConstructorParameters<typeof Intl.DateTimeFormat>
    ) {
      // A `function` (not arrow) so vitest can invoke the mock with `new`;
      // returning the real formatter makes formatToParts available downstream.
      return new Original(...args);
    } as typeof Intl.DateTimeFormat);
    localHour(new Date('2026-07-09T12:00:00Z'), zone);
    localHour(new Date('2026-07-09T18:30:00Z'), zone);
    expect(spy).toHaveBeenCalledTimes(1);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });
});

describe('isQuietLocalHour', () => {
  it('is quiet for 22:00–08:00 couple-local and open otherwise (full boundary table)', () => {
    const quiet = new Set([22, 23, 0, 1, 2, 3, 4, 5, 6, 7]);
    for (let hour = 0; hour <= 23; hour += 1) {
      expect(isQuietLocalHour(hour)).toBe(quiet.has(hour));
    }
  });

  it('is right-open at 08:00 and left-open at 22:00 (the exact boundaries)', () => {
    expect(isQuietLocalHour(7)).toBe(true); // still quiet
    expect(isQuietLocalHour(8)).toBe(false); // window ends at 08:00
    expect(isQuietLocalHour(21)).toBe(false); // not yet quiet
    expect(isQuietLocalHour(22)).toBe(true); // window opens at 22:00
  });

  it('leaves the hour-20 streak-at-risk sweep outside the quiet window', () => {
    expect(isQuietLocalHour(20)).toBe(false);
  });
});
