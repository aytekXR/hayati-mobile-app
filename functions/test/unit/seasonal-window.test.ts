import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { afterEach, describe, expect, it, vi } from 'vitest';

import {
  SEASONAL_WINDOWS,
  type SeasonalWindow,
  hijriCalendarAvailable,
  hijriDateOf,
  isSeasonalWindowOpen,
  openSeasonalWindows,
} from '../../src/rollover/seasonal-window';

// ADR-026: the window→date mapping. The fixture is the contract AND the ICU
// drift guard — every row was verified against Node 20 full-ICU when the ADR
// was written, so a future ICU data revision that moves an Umm al-Qura date
// reddens here instead of quietly shifting the product (D8).
const FIXTURE_PATH = fileURLToPath(
  new URL('../fixtures/seasonal-window-cases.json', import.meta.url),
);

interface WindowCase {
  dayKey: string;
  hijri: string;
  open: SeasonalWindow[];
  note: string;
}

const fixture = JSON.parse(readFileSync(FIXTURE_PATH, 'utf8')) as {
  policy: string;
  windows: SeasonalWindow[];
  cases: WindowCase[];
};

function hijriString(date: { year: number; month: number; day: number }): string {
  return (
    `${String(date.year).padStart(4, '0')}-` +
    `${String(date.month).padStart(2, '0')}-` +
    `${String(date.day).padStart(2, '0')}`
  );
}

describe('seasonal window fixture', () => {
  it('declares exactly the shipped vocabulary', () => {
    expect(fixture.windows).toEqual([...SEASONAL_WINDOWS]);
  });

  it('carries both sides of both edges for every window', () => {
    for (const window of SEASONAL_WINDOWS) {
      const inside = fixture.cases.filter((c) => c.open.includes(window));
      expect(inside.length, `${window} has no in-window case`).toBeGreaterThanOrEqual(2);
      // An entry edge is an in-window case whose immediately preceding fixture
      // row is out-of-window, and vice versa for the exit edge. Both must exist
      // or an off-by-one at that boundary would go unnoticed (CAL-1).
      const index = new Map(fixture.cases.map((c, i) => [c.dayKey, i]));
      const hasEntryEdge = inside.some((c) => {
        const before = fixture.cases[index.get(c.dayKey)! - 1];
        return before !== undefined && !before.open.includes(window);
      });
      const hasExitEdge = inside.some((c) => {
        const after = fixture.cases[index.get(c.dayKey)! + 1];
        return after !== undefined && !after.open.includes(window);
      });
      expect(hasEntryEdge, `${window} has no outside→inside entry edge`).toBe(true);
      expect(hasExitEdge, `${window} has no inside→outside exit edge`).toBe(true);
    }
  });

  it('pins both a 30-day and a 29-day Ramadan (the month-length trap)', () => {
    const lastDays = fixture.cases
      .filter((c) => c.open.includes('ramadan'))
      .map((c) => Number(c.hijri.slice(-2)));
    expect(lastDays).toContain(30);
    expect(lastDays).toContain(29);
  });
});

describe('hijriDateOf', () => {
  fixture.cases.forEach(({ dayKey, hijri, note }) => {
    it(`${dayKey} → ${hijri} (${note})`, () => {
      const date = hijriDateOf(dayKey);
      expect(
        date === null ? null : hijriString(date),
        `Umm al-Qura mismatch for ${dayKey} ` +
          `(node ${process.version}, ICU ${process.versions.icu ?? '?'}) — ` +
          'ICU data drift or a broken conversion',
      ).toBe(hijri);
    });
  });

  it('rejects a malformed dayKey loudly rather than guessing a date', () => {
    for (const bad of ['', '2026021', '2026-02-18', '20260231', 'abcdefgh', '20261318']) {
      expect(() => hijriDateOf(bad), `accepted '${bad}'`).toThrowError(/dayKey/);
    }
  });
});

describe('isSeasonalWindowOpen', () => {
  fixture.cases.forEach(({ dayKey, open, note }) => {
    it(`${dayKey} opens exactly [${open.join(', ')}] (${note})`, () => {
      for (const window of SEASONAL_WINDOWS) {
        expect(isSeasonalWindowOpen(window, dayKey), `${window} @ ${dayKey}`).toBe(
          open.includes(window),
        );
      }
      expect([...openSeasonalWindows(dayKey)].sort()).toEqual([...open].sort());
    });
  });
});

// D2/D8: the dangerous mode is not a thrown error — Intl SILENTLY resolves an
// unsupported calendar to 'gregory', which would make month 9 read as
// September and fire Ramadan every autumn, forever, with nothing red. This
// installs that exact degradation (resolvedOptions is writable+configurable on
// Node 20) and proves the guard both DETECTS it and fails toward CLOSED.
describe('when the runtime cannot do Umm al-Qura (the silent-Gregorian mode)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.resetModules();
  });

  async function importUnderDegradedIcu(): Promise<
    typeof import('../../src/rollover/seasonal-window')
  > {
    const original = Intl.DateTimeFormat.prototype.resolvedOptions;
    vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions').mockImplementation(
      function (this: Intl.DateTimeFormat) {
        return { ...original.call(this), calendar: 'gregory' };
      },
    );
    // Fresh module instance so the memoised verdict is computed under the spy.
    vi.resetModules();
    return import('../../src/rollover/seasonal-window');
  }

  it('reports the calendar unavailable', async () => {
    const mod = await importUnderDegradedIcu();
    expect(mod.hijriCalendarAvailable()).toBe(false);
  });

  it('returns null for every dayKey instead of Gregorian numbers', async () => {
    const mod = await importUnderDegradedIcu();
    for (const { dayKey } of fixture.cases) {
      expect(mod.hijriDateOf(dayKey)).toBeNull();
    }
  });

  it('reports every Hijri window CLOSED on dates the fixture proves are inside it', async () => {
    const mod = await importUnderDegradedIcu();
    const hijriWindows: SeasonalWindow[] = ['ramadan', 'eid_fitr', 'eid_adha'];
    for (const window of hijriWindows) {
      const insideCases = fixture.cases.filter((c) => c.open.includes(window));
      expect(insideCases.length).toBeGreaterThan(0);
      for (const { dayKey } of insideCases) {
        expect(mod.isSeasonalWindowOpen(window, dayKey), `${window} @ ${dayKey}`).toBe(false);
      }
    }
  });

  it('does NOT fire ramadan in September (the exact silent-Gregorian symptom)', async () => {
    const mod = await importUnderDegradedIcu();
    // 2026-09-14 is Gregorian month 9. A Gregorian fallback read as Hijri
    // would open ramadan here; the guard must keep it shut.
    expect(mod.isSeasonalWindowOpen('ramadan', '20260914')).toBe(false);
    expect(mod.openSeasonalWindows('20260914')).toEqual([]);
  });

  it('leaves the Gregorian new_year window working', async () => {
    const mod = await importUnderDegradedIcu();
    expect(mod.isSeasonalWindowOpen('new_year', '20261231')).toBe(true);
    expect(mod.isSeasonalWindowOpen('new_year', '20270101')).toBe(true);
    expect(mod.isSeasonalWindowOpen('new_year', '20270102')).toBe(false);
  });
});

describe('hijriCalendarAvailable', () => {
  it('is true on this runtime (full ICU) — the fixture rows above depend on it', () => {
    expect(hijriCalendarAvailable()).toBe(true);
  });
});
