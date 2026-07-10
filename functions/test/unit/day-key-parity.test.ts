import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { localDayKey } from '../../src/rollover/day-key';

// M3.3 (ADR-011 binding contract): the app computes the couple dayKey from
// the STORED couples.timezone with a Dart mirror of localDayKey — the two
// implementations must agree byte-for-byte or the app reads the wrong day
// doc around midnight. This suite pins the TS side of the shared fixture;
// app/test/features/daily_question/domain/couple_day_key_test.dart pins the
// Dart side against the SAME file. The fixture header documents the
// rule-stable-zones-only policy that keeps tzdata skew out of the equation.
const FIXTURE_PATH = fileURLToPath(
  new URL('../fixtures/day-key-parity.json', import.meta.url),
);

interface ParityCase {
  instant: string;
  zone: string;
  dayKey: string;
}

const fixture = JSON.parse(readFileSync(FIXTURE_PATH, 'utf8')) as {
  policy: string;
  cases: ParityCase[];
};

describe('localDayKey ↔ coupleDayKey parity fixture (TS side)', () => {
  it('carries a usable spread: boundaries, DST shifts, sub-hour offsets', () => {
    expect(fixture.cases.length).toBeGreaterThanOrEqual(15);
    const zones = new Set(fixture.cases.map((c) => c.zone));
    for (const zone of [
      'Europe/Istanbul',
      'America/New_York',
      'Europe/London',
      'Asia/Kathmandu',
      'Pacific/Chatham',
    ]) {
      expect(zones).toContain(zone);
    }
  });

  fixture.cases.forEach(({ instant, zone, dayKey }) => {
    it(`${instant} @ ${zone} → ${dayKey}`, () => {
      let actual: string;
      try {
        actual = localDayKey(new Date(instant), zone);
      } catch (error) {
        throw new Error(
          `localDayKey threw for ${zone} — tzdata missing the zone? ` +
            `(node ${process.version}, ICU ${process.versions.icu ?? '?'}, ` +
            `tz ${process.versions.tz ?? '?'}): ${String(error)}`,
        );
      }
      expect(
        actual,
        `parity mismatch for ${instant} @ ${zone} ` +
          `(node ${process.version}, ICU ${process.versions.icu ?? '?'}, ` +
          `tz ${process.versions.tz ?? '?'}) — tzdata skew or broken mirror`,
      ).toBe(dayKey);
    });
  });
});
