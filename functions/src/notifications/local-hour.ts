// Pure couple-local wall-clock hour for the M3.4 push policy (ADR-012 decision
// 3: "quiet hours 22:00–08:00 in the couple's STORED timezone"). The sibling of
// rollover/day-key.ts — same instant→zone projection, same formatter discipline
// — but it extracts the HOUR (0..23) instead of the yyyymmdd date. Intl does the
// DST-correct projection: the zone's offset (and any half-hour or DST shift)
// falls out of formatToParts, no hour arithmetic ever happens here.

// Formatter construction is the expensive part of Intl; the hourly sweep asks
// for the same handful of zones repeatedly (once per couple), so cache per zone
// exactly like day-key.ts. An invalid zone id throws RangeError out of the
// constructor before anything is cached — couple timezones are allow-listed at
// join (resolveCoupleTimezone), so an unknown id is corrupt state to surface,
// not to guess a quiet-hours decision around.
const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (formatter === undefined) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      // Pin the clock AND the digits: `hourCycle: 'h23'` forces the 0..23 cycle
      // so LOCAL MIDNIGHT reads 00, never 24 (h24 would emit "24" at midnight and
      // break the quiet-window comparison); `numberingSystem: 'latn'` forces ASCII
      // digits so Number() parses them regardless of the runtime's locale defaults
      // (an Arabic/Persian numbering system would yield non-parseable glyphs).
      hourCycle: 'h23',
      numberingSystem: 'latn',
      hour: '2-digit',
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

/** The 0..23 wall-clock hour of `instant` in `timeZone` (local midnight → 0). */
export function localHour(instant: Date, timeZone: string): number {
  const parts = formatterFor(timeZone).formatToParts(instant);
  const hourPart = parts.find((p) => p.type === 'hour');
  if (hourPart === undefined) {
    throw new Error("Intl.DateTimeFormat returned no 'hour' part");
  }
  // `% 24` makes the "midnight is 0, never 24" invariant total: h23 already
  // pins it, but should any engine's ICU emit "24" for midnight, 24 % 24 === 0
  // keeps the contract rather than leaking an out-of-range hour into the policy.
  return Number(hourPart.value) % 24;
}

/**
 * True inside the couple-local quiet window 22:00–08:00 (ADR-012: pushes in this
 * window are SUPPRESSED, not queued — no scheduling infra this session). The
 * window is right-open at 08:00: hours 22, 23, 0..7 are quiet; 8 and 21 are not.
 * The streak-at-risk push fires at local hour 20, outside the window by
 * construction.
 */
export function isQuietLocalHour(hour: number): boolean {
  return hour >= 22 || hour < 8;
}
