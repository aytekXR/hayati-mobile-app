// Seasonal window → date resolution (ADR-026, closing ADR-011 D4's deferral
// and issue #29). Pure: the only input is the couple's own dayKey — the
// yyyymmdd id of the day doc being assigned — never the wall clock. That is
// what keeps selection racer-invariant: two overlapping sweeps writing the
// same days/{dayKey} derive the same verdict from the same id (ADR-026 D1).
// The couple's timezone is deliberately NOT an input here; it already did its
// work producing the dayKey.
//
// Hijri comes from ICU's Umm al-Qura civil calendar via Intl — the same
// primitive day-key.ts trusts, so no dependency and no calendar table to age.
// Umm al-Qura is a CALCULATED calendar: real observance (Diyanet's astronomical
// reckoning, Gulf sighting) can differ by a day either way. Windows are
// deliberately NOT padded for that — padding eid_fitr backwards would put an
// Eid greeting on the last fasting day, a worse error than the one it fixes
// (ADR-026 D5).

/** The closed seasonal vocabulary. Adding one is a five-reader change (ADR-026 D3). */
export const SEASONAL_WINDOWS = ['ramadan', 'eid_fitr', 'eid_adha', 'new_year'] as const;

export type SeasonalWindow = (typeof SEASONAL_WINDOWS)[number];

/** True for a string in the closed vocabulary — the narrowing both parsers use. */
export function isSeasonalWindow(value: unknown): value is SeasonalWindow {
  return typeof value === 'string' && (SEASONAL_WINDOWS as readonly string[]).includes(value);
}

/** A Umm al-Qura calendar date. `month` is 1..12, `day` is 1..30. */
export interface HijriDate {
  readonly year: number;
  readonly month: number;
  readonly day: number;
}

const DAY_KEY_PATTERN = /^(\d{4})(\d{2})(\d{2})$/;

// Intl SILENTLY ignores an unsupported calendar and resolves to 'gregory'
// (verified: `{calendar:'nonexist'}` -> resolved 'gregory', no throw). On a
// runtime with trimmed ICU that would make Hijri month 9 read as SEPTEMBER and
// fire ramadan every autumn, for every couple, forever, with nothing red. So
// the formatter is only ever handed out after resolvedOptions() confirms what
// ICU actually used. Lazy + memoised so a test can install the degradation and
// re-import the module to exercise the failure path (ADR-026 D2/D8).
let probe: { formatter: Intl.DateTimeFormat | null } | undefined;

function umAlQuraFormatter(): Intl.DateTimeFormat | null {
  if (probe === undefined) {
    const formatter = new Intl.DateTimeFormat('en-US', {
      calendar: 'islamic-umalqura',
      // Pinned for the same reason day-key.ts pins them: Intl defaults derive
      // from the LOCALE, so non-ASCII digits would corrupt every comparison.
      numberingSystem: 'latn',
      timeZone: 'UTC',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
    });
    const resolved = formatter.resolvedOptions();
    const usable =
      resolved.calendar === 'islamic-umalqura' && resolved.numberingSystem === 'latn';
    probe = { formatter: usable ? formatter : null };
  }
  return probe.formatter;
}

/**
 * Whether this runtime can actually resolve Umm al-Qura dates. False means
 * every HIJRI window is reported CLOSED (fail-closed on content, fail-open on
 * availability — evergreen selection keeps working). The rollover sweep reads
 * this once and logs it loudly; see runQuestionRollover (ADR-026 D2).
 */
export function hijriCalendarAvailable(): boolean {
  return umAlQuraFormatter() !== null;
}

function part(parts: Intl.DateTimeFormatPart[], type: 'year' | 'month' | 'day'): number {
  const found = parts.find((p) => p.type === type);
  if (found === undefined) {
    throw new Error(`Intl.DateTimeFormat returned no '${type}' part`);
  }
  const value = Number(found.value);
  if (!Number.isInteger(value)) {
    throw new Error(`Intl.DateTimeFormat returned a non-numeric '${type}': ${found.value}`);
  }
  return value;
}

/** The Gregorian calendar date a dayKey names, as a UTC-noon instant. */
function instantOf(dayKey: string): Date {
  const match = DAY_KEY_PATTERN.exec(dayKey);
  if (match === null) {
    throw new Error(`seasonal window: malformed dayKey '${dayKey}' (yyyymmdd required)`);
  }
  const [, year, month, day] = match;
  // Noon UTC keeps the calendar→calendar conversion far from any date
  // boundary; UTC in, UTC out, so no offset arithmetic exists to get wrong.
  const instant = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), 12));
  // Date.UTC silently rolls over an impossible date (Feb 31 -> Mar 3). A dayKey
  // is a doc id, never user input, so a rollover here means corrupt state:
  // surface it rather than seasonally mis-assign a day that does not exist.
  if (
    instant.getUTCFullYear() !== Number(year) ||
    instant.getUTCMonth() !== Number(month) - 1 ||
    instant.getUTCDate() !== Number(day)
  ) {
    throw new Error(`seasonal window: dayKey '${dayKey}' is not a real calendar date`);
  }
  return instant;
}

/**
 * The Umm al-Qura date of `dayKey`'s Gregorian calendar date, or `null` when
 * this runtime cannot do Umm al-Qura. Throws only for a malformed dayKey.
 */
export function hijriDateOf(dayKey: string): HijriDate | null {
  const instant = instantOf(dayKey);
  const formatter = umAlQuraFormatter();
  if (formatter === null) {
    return null;
  }
  const parts = formatter.formatToParts(instant);
  return {
    year: part(parts, 'year'),
    month: part(parts, 'month'),
    day: part(parts, 'day'),
  };
}

/** The Gregorian (month, day) of a dayKey — used by the non-Hijri windows. */
function gregorianMonthDay(dayKey: string): { month: number; day: number } {
  const instant = instantOf(dayKey);
  return { month: instant.getUTCMonth() + 1, day: instant.getUTCDate() };
}

// Hijri month/day-range table. Ramadan is the WHOLE month, so it is
// length-agnostic by construction (Hijri months run 29 or 30 days and both
// occur in the fixture). Eid al-Fitr is Shawwal 1-3; Eid al-Adha is
// Dhu al-Hijjah 10-13.
const HIJRI_WINDOWS: Readonly<Record<string, { month: number; from: number; to: number }>> = {
  ramadan: { month: 9, from: 1, to: 30 },
  eid_fitr: { month: 10, from: 1, to: 3 },
  eid_adha: { month: 12, from: 10, to: 13 },
};

/** Whether `window` is open on the couple-local calendar day `dayKey`. */
export function isSeasonalWindowOpen(window: SeasonalWindow, dayKey: string): boolean {
  if (window === 'new_year') {
    // Deliberately straddles the Gregorian year boundary (ADR-026 D6), so it
    // cannot be expressed as one (month, day) range comparison.
    const { month, day } = gregorianMonthDay(dayKey);
    return (month === 12 && day === 31) || (month === 1 && day === 1);
  }
  const range = HIJRI_WINDOWS[window];
  /* istanbul ignore next -- exhaustive over SEASONAL_WINDOWS; unreachable */
  if (range === undefined) {
    return false;
  }
  const hijri = hijriDateOf(dayKey);
  if (hijri === null) {
    return false;
  }
  return hijri.month === range.month && hijri.day >= range.from && hijri.day <= range.to;
}

/** Every window open on `dayKey`, in vocabulary order. */
export function openSeasonalWindows(dayKey: string): SeasonalWindow[] {
  return SEASONAL_WINDOWS.filter((window) => isSeasonalWindowOpen(window, dayKey));
}
