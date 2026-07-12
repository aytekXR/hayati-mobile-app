// Pure-core unit tests for coach-core (ADR-016 Decisions 1/6/7/8): request
// validation matrix, cap reserve/refund arithmetic (lazy reset, both-cap
// interplay, per-lane captured-key mismatch, floor 0), the PII-safe log builder,
// and period-key derivation against real zones. No emulator.
import { describe, expect, expectTypeOf, it } from 'vitest';

import {
  CoachEventLog,
  DEFAULT_CAPS,
  MAX_MESSAGE_CHARS,
  MAX_MESSAGES,
  SCAN_CHAR_LIMIT,
  computePeriodKeys,
  logCoachEvent,
  planRefund,
  planReserve,
  truncateForScan,
  validateCoachRequest,
} from '../../src/coach/coach-core';

// A valid request body; overrides replace individual fields per case.
function body(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    coupleId: 'couple-1',
    personaId: 'coach',
    language: 'tr',
    register: 'tr-playful',
    messages: [{ role: 'user', text: 'merhaba' }],
    ...overrides,
  };
}

describe('validateCoachRequest — Decision 1 bounds + enums', () => {
  it('accepts a well-formed request and returns the typed request', () => {
    const result = validateCoachRequest(body());
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.request.coupleId).toBe('couple-1');
      expect(result.request.messages).toEqual([{ role: 'user', text: 'merhaba' }]);
    }
  });

  it('accepts every persona / language / register enum member', () => {
    for (const personaId of ['coach', 'dateGenie', 'giftGenie']) {
      expect(validateCoachRequest(body({ personaId })).ok).toBe(true);
    }
    for (const language of ['tr', 'ar', 'en']) {
      const register = language === 'en' ? 'en-neutral' : language === 'ar' ? 'ar-gulf-respectful' : 'tr-playful';
      expect(validateCoachRequest(body({ language, register })).ok).toBe(true);
    }
    for (const register of ['tr-playful', 'tr-respectful', 'ar-gulf-respectful', 'en-neutral']) {
      expect(validateCoachRequest(body({ register })).ok).toBe(true);
    }
  });

  it('accepts exactly MAX_MESSAGES with a trailing user turn', () => {
    const messages = Array.from({ length: MAX_MESSAGES }, (_v, i) => ({
      role: i % 2 === 0 ? 'user' : 'assistant',
      text: `m${i}`,
    }));
    messages[messages.length - 1] = { role: 'user', text: 'last' };
    expect(validateCoachRequest(body({ messages })).ok).toBe(true);
  });

  it('accepts a message at exactly MAX_MESSAGE_CHARS', () => {
    expect(validateCoachRequest(body({ messages: [{ role: 'user', text: 'x'.repeat(MAX_MESSAGE_CHARS) }] })).ok).toBe(
      true,
    );
  });

  it.each([
    ['not-object', 'nope'],
    ['not-object', null],
    ['not-object', []],
    ['bad-coupleId', body({ coupleId: '' })],
    ['bad-coupleId', body({ coupleId: 42 })],
    ['bad-personaId', body({ personaId: 'wizard' })],
    ['bad-personaId', body({ personaId: undefined })],
    ['bad-language', body({ language: 'fr' })],
    ['bad-register', body({ register: 'tr-sassy' })],
    ['bad-register', body({ register: undefined })],
    ['bad-messages', body({ messages: 'not-an-array' })],
    ['no-messages', body({ messages: [] })],
    ['too-many-messages', body({ messages: Array.from({ length: MAX_MESSAGES + 1 }, () => ({ role: 'user', text: 'x' })) })],
    ['bad-message', body({ messages: [{ role: 'system', text: 'x' }] })],
    ['bad-message', body({ messages: [{ role: 'user', text: 42 }] })],
    ['bad-message', body({ messages: [null] })],
    ['message-too-long', body({ messages: [{ role: 'user', text: 'x'.repeat(MAX_MESSAGE_CHARS + 1) }] })],
    ['last-not-user', body({ messages: [{ role: 'user', text: 'hi' }, { role: 'assistant', text: 'yo' }] })],
  ] as const)('rejects with reason %s', (reason, input) => {
    const result = validateCoachRequest(input);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.reason).toBe(reason);
    }
  });
});

describe('truncateForScan — Decision 2', () => {
  it('leaves a legit-length message untouched', () => {
    expect(truncateForScan('short')).toBe('short');
  });

  it('truncates an oversized payload to SCAN_CHAR_LIMIT', () => {
    const truncated = truncateForScan('a'.repeat(SCAN_CHAR_LIMIT + 500));
    expect(truncated.length).toBe(SCAN_CHAR_LIMIT);
  });

  it('SCAN_CHAR_LIMIT is double the legit per-message maximum', () => {
    expect(SCAN_CHAR_LIMIT).toBe(MAX_MESSAGE_CHARS * 2);
  });
});

describe('computePeriodKeys — Decision 7 (couple-local, ADR-011 localDayKey)', () => {
  it('Europe/Istanbul: the 21:00Z rollover lands on the next local day', () => {
    const before = computePeriodKeys(Date.parse('2026-07-09T20:59:59Z'), 'Europe/Istanbul');
    const after = computePeriodKeys(Date.parse('2026-07-09T21:00:00Z'), 'Europe/Istanbul');
    expect(before).toEqual({ dayKey: '20260709', monthKey: '202607' });
    expect(after).toEqual({ dayKey: '20260710', monthKey: '202607' });
  });

  it('Asia/Riyadh: same instant, same local day and month prefix', () => {
    expect(computePeriodKeys(Date.parse('2026-07-09T21:00:00Z'), 'Asia/Riyadh')).toEqual({
      dayKey: '20260710',
      monthKey: '202607',
    });
  });

  it('monthKey is always the yyyymm prefix of the dayKey', () => {
    const keys = computePeriodKeys(Date.parse('2026-01-31T00:00:00Z'), 'Europe/Istanbul');
    expect(keys.monthKey).toBe(keys.dayKey.slice(0, 6));
  });
});

describe('planReserve — Decision 7 lazy reset + both-cap interplay', () => {
  const caps = { dailyPerUser: 30, monthlyPerCouple: 1000 };
  const base = { dayKey: '20260710', monthKey: '202607', caps };

  it('reserves from a clean slate (both lanes absent → count 1)', () => {
    const result = planReserve({ ...base, parentMonthly: null, dailyLane: null });
    expect(result).toEqual({
      kind: 'reserved',
      newDaily: { dayKey: '20260710', count: 1 },
      newParent: { monthKey: '202607', count: 1 },
      remaining: { daily: 29, monthly: 999 },
    });
  });

  it('lazily resets a stale daily lane (different dayKey → treated as 0)', () => {
    const result = planReserve({
      ...base,
      parentMonthly: { monthKey: '202607', count: 5 },
      dailyLane: { dayKey: '20260709', count: 30 }, // yesterday, at cap — must not block
    });
    expect(result).toMatchObject({ kind: 'reserved', newDaily: { count: 1 }, newParent: { count: 6 } });
  });

  it('lazily resets a stale monthly bucket (different monthKey → treated as 0)', () => {
    const result = planReserve({
      ...base,
      parentMonthly: { monthKey: '202606', count: 1000 }, // last month, at cap
      dailyLane: { dayKey: '20260710', count: 3 },
    });
    expect(result).toMatchObject({ kind: 'reserved', newDaily: { count: 4 }, newParent: { count: 1 } });
  });

  it('daily cap exceeded → cap-daily, no reserve', () => {
    expect(
      planReserve({ ...base, parentMonthly: { monthKey: '202607', count: 5 }, dailyLane: { dayKey: '20260710', count: 30 } }),
    ).toEqual({ kind: 'cap-exceeded', which: 'cap-daily' });
  });

  it('monthly cap exceeded (daily clear) → cap-monthly', () => {
    expect(
      planReserve({ ...base, parentMonthly: { monthKey: '202607', count: 1000 }, dailyLane: { dayKey: '20260710', count: 3 } }),
    ).toEqual({ kind: 'cap-exceeded', which: 'cap-monthly' });
  });

  it('both caps exceeded → cap-daily wins (documented daily-first precedence)', () => {
    expect(
      planReserve({ ...base, parentMonthly: { monthKey: '202607', count: 1000 }, dailyLane: { dayKey: '20260710', count: 30 } }),
    ).toEqual({ kind: 'cap-exceeded', which: 'cap-daily' });
  });

  it('the last unit under each cap still reserves (boundary is exclusive of the cap)', () => {
    const result = planReserve({
      ...base,
      parentMonthly: { monthKey: '202607', count: 999 },
      dailyLane: { dayKey: '20260710', count: 29 },
    });
    expect(result).toMatchObject({ kind: 'reserved', remaining: { daily: 0, monthly: 0 } });
  });

  it('DEFAULT_CAPS carries the PRD/ADR values', () => {
    expect(DEFAULT_CAPS).toEqual({ dailyPerUser: 30, monthlyPerCouple: 1000 });
  });
});

describe('planRefund — Decision 7 per-lane captured-key guard, floor 0', () => {
  const reserved = { reservedDayKey: '20260710', reservedMonthKey: '202607' };

  it('both keys still match → both lanes decrement', () => {
    expect(
      planRefund({ ...reserved, dailyLane: { dayKey: '20260710', count: 5 }, parentMonthly: { monthKey: '202607', count: 8 } }),
    ).toEqual({ daily: { write: true, count: 4 }, monthly: { write: true, count: 7 } });
  });

  it('daily lane rolled over (key mismatch) → writes NOTHING to daily, still refunds monthly', () => {
    // The 23:59 reserve refunded at 00:01: the daily boundary crossed, the monthly did not.
    expect(
      planRefund({ ...reserved, dailyLane: { dayKey: '20260711', count: 2 }, parentMonthly: { monthKey: '202607', count: 8 } }),
    ).toEqual({ daily: { write: false }, monthly: { write: true, count: 7 } });
  });

  it('monthly bucket rolled over → writes NOTHING to monthly, still refunds daily', () => {
    expect(
      planRefund({ ...reserved, dailyLane: { dayKey: '20260710', count: 5 }, parentMonthly: { monthKey: '202608', count: 1 } }),
    ).toEqual({ daily: { write: true, count: 4 }, monthly: { write: false } });
  });

  it('floor 0 — a refund never drives a count negative', () => {
    expect(
      planRefund({ ...reserved, dailyLane: { dayKey: '20260710', count: 0 }, parentMonthly: { monthKey: '202607', count: 0 } }),
    ).toEqual({ daily: { write: true, count: 0 }, monthly: { write: true, count: 0 } });
  });

  it('absent lanes → nothing to refund', () => {
    expect(planRefund({ ...reserved, dailyLane: null, parentMonthly: null })).toEqual({
      daily: { write: false },
      monthly: { write: false },
    });
  });
});

describe('logCoachEvent — Decision 8 privacy-by-construction', () => {
  it('the log TYPE has no `text`/message field and no `uid` field', () => {
    expectTypeOf<CoachEventLog>().not.toHaveProperty('uid');
    expectTypeOf<CoachEventLog>().not.toHaveProperty('text');
    expectTypeOf<CoachEventLog>().not.toHaveProperty('message');
  });

  it('a persona reply carries coupleId, personaId and the cap hints', () => {
    const event = logCoachEvent({
      outcome: 'reply',
      language: 'tr',
      coupleId: 'couple-1',
      personaId: 'coach',
      capRemainingDaily: 29,
      capRemainingMonthly: 999,
      latencyMs: 120,
    });
    expect(event).toEqual({
      outcome: 'reply',
      language: 'tr',
      coupleId: 'couple-1',
      personaId: 'coach',
      capRemainingDaily: 29,
      capRemainingMonthly: 999,
      latencyMs: 120,
    });
  });

  it.each(['crisis', 'help-path'] as const)('a %s outcome OMITS coupleId (and personaId/caps)', (outcome) => {
    const event = logCoachEvent({
      outcome,
      language: 'ar',
      coupleId: 'couple-1',
      personaId: 'coach',
      capRemainingDaily: 5,
      capRemainingMonthly: 5,
      latencyMs: 40,
    });
    expect(event).toEqual({ outcome, language: 'ar', latencyMs: 40 });
    expect(Object.keys(event)).not.toContain('coupleId');
    expect(Object.keys(event)).not.toContain('personaId');
  });

  it('a non-crisis error outcome keeps its errorCode', () => {
    const event = logCoachEvent({ outcome: 'unavailable', language: 'en', errorCode: 'upstream-error', latencyMs: 90 });
    expect(event).toEqual({ outcome: 'unavailable', language: 'en', errorCode: 'upstream-error', latencyMs: 90 });
  });
});
