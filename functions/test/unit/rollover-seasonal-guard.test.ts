import { beforeAll, afterAll, describe, expect, it, vi } from 'vitest';

import type { CoupleBuckets } from '../../src/rollover/rollover-service';

// ADR-026 D2 mechanism 3+4: the sweep probes the calendar ONCE, surfaces the
// verdict on the run summary and logs it. seasonal-window.test.ts proves the
// PREDICATE fails closed under a degraded ICU; this file proves the sweep-level
// half — that the refusal is visible rather than swallowed. Without it the
// `if (!hijriCalendarAvailable())` block in rollover-service.ts is a branch no
// test ever enters, and the ADR's own standard ("a guard whose failure nothing
// observes is decoration") would not be met at this layer.
//
// The degradation is installed BEFORE the service is imported, because the
// module memoises its calendar verdict on first use. The sweep is driven with
// an EMPTY precomputed bucketing, which is the one shape that reaches the probe
// without touching Firestore — so this stays a plain unit test.

const originalResolvedOptions = Intl.DateTimeFormat.prototype.resolvedOptions;

let runQuestionRollover: typeof import('../../src/rollover/rollover-service').runQuestionRollover;
let errorSpy: ReturnType<typeof vi.spyOn>;

beforeAll(async () => {
  vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions').mockImplementation(
    function (this: Intl.DateTimeFormat) {
      return { ...originalResolvedOptions.call(this), calendar: 'gregory' };
    },
  );
  vi.resetModules();
  const functions = await import('firebase-functions');
  errorSpy = vi.spyOn(functions.logger, 'error').mockImplementation(() => undefined);
  ({ runQuestionRollover } = await import('../../src/rollover/rollover-service'));
});

afterAll(() => {
  vi.restoreAllMocks();
  vi.resetModules();
});

const EMPTY_BUCKETS: CoupleBuckets = { buckets: new Map(), skips: [] };

describe('runQuestionRollover when the runtime cannot do Umm al-Qura', () => {
  it('surfaces the degradation on the run summary instead of swallowing it', async () => {
    const summary = await runQuestionRollover(
      null as never, // never touched: an empty precomputed bucketing reads nothing
      new Date('2026-02-18T09:00:00Z'), // inside Ramadan 1447 — the window that will NOT open
      undefined,
      EMPTY_BUCKETS,
    );

    expect(summary.seasonalCalendarUnavailable).toBe(true);
    expect(summary.failed).toBe(0);
  });

  it('logs it exactly once per sweep, naming the consequence', async () => {
    errorSpy.mockClear();

    await runQuestionRollover(null as never, new Date(), undefined, EMPTY_BUCKETS);

    const calendarLogs = errorSpy.mock.calls.filter((call: unknown[]) =>
      String(call[0]).includes('Umm al-Qura'),
    );
    expect(calendarLogs).toHaveLength(1);
    expect(String(calendarLogs[0][0])).toMatch(/treated as CLOSED/);
  });
});
