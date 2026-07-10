// Pure local-calendar-date core for the M3.2 rollover (docs/architecture.md
// §3/§4, ADR-011). dayKey is the couple's LOCAL calendar date as yyyymmdd —
// the id of couples/{cid}/days/{yyyymmdd} and the same shape the app's
// soloDayKey produces (solo_day.dart). Intl.DateTimeFormat does the
// instant→zone-local date projection, which is DST-correct by construction:
// the zone's UTC midnight boundary moves with its offset and no hour
// arithmetic ever happens here.

// Formatter construction is the expensive part of Intl; the hourly sweep asks
// for the same handful of zones repeatedly, so cache per zone. An invalid
// zone id throws RangeError out of the constructor before anything is cached
// — couple timezones are allow-listed at join (resolveCoupleTimezone), so an
// unknown id is corrupt state to surface, not to guess around.
const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (formatter === undefined) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      // Pin calendar AND digits: Intl defaults derive from the LOCALE, not
      // the zone — an Arabic/Persian locale default would emit Hijri/Persian
      // dates or non-ASCII digits, silently corrupting every doc id. dayKeys
      // must always be 8 ASCII digits of the Gregorian calendar, byte-equal
      // to the app's soloDayKey shape.
      calendar: 'gregory',
      numberingSystem: 'latn',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

function part(parts: Intl.DateTimeFormatPart[], type: 'year' | 'month' | 'day'): string {
  const found = parts.find((p) => p.type === type);
  if (found === undefined) {
    throw new Error(`Intl.DateTimeFormat returned no '${type}' part`);
  }
  return found.value;
}

/** The yyyymmdd key of `instant`'s calendar date in `timeZone`. */
export function localDayKey(instant: Date, timeZone: string): string {
  const parts = formatterFor(timeZone).formatToParts(instant);
  return (
    part(parts, 'year').padStart(4, '0') + part(parts, 'month') + part(parts, 'day')
  );
}
