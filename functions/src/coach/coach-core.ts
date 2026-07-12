// Pure decision core for the M5.1 coach service (ADR-016 Decisions 1/6/7/8). All
// total functions over plain values — no Firestore, no I/O — so request
// validation, the cap reserve/refund arithmetic, the period-key derivation and
// the PII-safe log shape are exhaustively unit-testable without the emulator (the
// entitlement-core.ts / streak.ts mold). The stage-2 service (coach-service.ts)
// drives the transaction and calls these; this module owns WHAT the rules are.

import { localDayKey } from '../rollover/day-key';
import {
  COACH_LANGUAGES,
  COACH_PERSONA_IDS,
  COACH_REGISTERS,
  CoachLanguage,
  CoachPersonaId,
  CoachRegister,
} from './provider-port';

// --- request validation (Decision 1) ---------------------------------------

/** Bounds frozen at the port shape (Decision 1); the wire is untrusted. */
export const MAX_MESSAGES = 20;
export const MAX_MESSAGE_CHARS = 2000;

export interface CoachMessage {
  role: 'user' | 'assistant';
  text: string;
}

/** A validated request (compile-time only; runtime validation is the guarantee). */
export interface CoachRequest {
  coupleId: string;
  personaId: CoachPersonaId;
  language: CoachLanguage;
  register: CoachRegister;
  messages: CoachMessage[];
}

/** Every way a request body fails Decision 1 — a static, enumerated reason. */
export type CoachValidationReason =
  | 'not-object'
  | 'bad-coupleId'
  | 'bad-personaId'
  | 'bad-language'
  | 'bad-register'
  | 'bad-messages'
  | 'no-messages'
  | 'too-many-messages'
  | 'bad-message'
  | 'message-too-long'
  | 'last-not-user';

export type CoachValidation =
  | { ok: true; request: CoachRequest }
  | { ok: false; reason: CoachValidationReason };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isPersona(value: unknown): value is CoachPersonaId {
  return typeof value === 'string' && (COACH_PERSONA_IDS as readonly string[]).includes(value);
}

function isLanguage(value: unknown): value is CoachLanguage {
  return typeof value === 'string' && (COACH_LANGUAGES as readonly string[]).includes(value);
}

function isRegister(value: unknown): value is CoachRegister {
  return typeof value === 'string' && (COACH_REGISTERS as readonly string[]).includes(value);
}

/**
 * Validates an untrusted request body against Decision 1: non-empty `coupleId`,
 * the three closed enums, 1..20 messages each ≤2,000 chars with a `role`/`text`
 * shape, and a final `role: 'user'` message. Returns a typed union — every
 * failure is a static, enumerated reason (the shell maps to `invalid-argument`
 * with a static message; nothing is interpolated from request text, Decision 8).
 * The order of checks is fixed so the reason is deterministic.
 */
export function validateCoachRequest(body: unknown): CoachValidation {
  if (!isRecord(body)) {
    return { ok: false, reason: 'not-object' };
  }
  if (typeof body.coupleId !== 'string' || body.coupleId.length === 0) {
    return { ok: false, reason: 'bad-coupleId' };
  }
  if (!isPersona(body.personaId)) {
    return { ok: false, reason: 'bad-personaId' };
  }
  if (!isLanguage(body.language)) {
    return { ok: false, reason: 'bad-language' };
  }
  if (!isRegister(body.register)) {
    return { ok: false, reason: 'bad-register' };
  }
  if (!Array.isArray(body.messages)) {
    return { ok: false, reason: 'bad-messages' };
  }
  if (body.messages.length === 0) {
    return { ok: false, reason: 'no-messages' };
  }
  if (body.messages.length > MAX_MESSAGES) {
    return { ok: false, reason: 'too-many-messages' };
  }
  const messages: CoachMessage[] = [];
  for (const raw of body.messages) {
    if (!isRecord(raw) || (raw.role !== 'user' && raw.role !== 'assistant') || typeof raw.text !== 'string') {
      return { ok: false, reason: 'bad-message' };
    }
    if (raw.text.length > MAX_MESSAGE_CHARS) {
      return { ok: false, reason: 'message-too-long' };
    }
    messages.push({ role: raw.role, text: raw.text });
  }
  if (messages[messages.length - 1].role !== 'user') {
    return { ok: false, reason: 'last-not-user' };
  }
  return {
    ok: true,
    request: {
      coupleId: body.coupleId,
      personaId: body.personaId,
      language: body.language,
      register: body.register,
      messages,
    },
  };
}

/** The scan truncation limit (Decision 2): double the legit per-message maximum. */
export const SCAN_CHAR_LIMIT = 4000;

/**
 * Truncate a message to the first `SCAN_CHAR_LIMIT` chars for the crisis scan
 * (Decision 2). At double the 2,000-char legit maximum, no well-formed content is
 * ever truncated; the cap only bounds a hostile oversized payload.
 */
export function truncateForScan(text: string): string {
  return text.length > SCAN_CHAR_LIMIT ? text.slice(0, SCAN_CHAR_LIMIT) : text;
}

// --- period keys + caps (Decision 6/7) --------------------------------------

/** Default caps (Decision 7); injected through the service deps seam. */
export const DAILY_PER_USER = 30;
export const MONTHLY_PER_COUPLE = 1000;

export interface CapConfig {
  dailyPerUser: number;
  monthlyPerCouple: number;
}

export const DEFAULT_CAPS: CapConfig = {
  dailyPerUser: DAILY_PER_USER,
  monthlyPerCouple: MONTHLY_PER_COUPLE,
};

export interface PeriodKeys {
  /** The couple-local yyyymmdd day key. */
  dayKey: string;
  /** The yyyymm prefix of the day key — the monthly bucket key. */
  monthKey: string;
}

/**
 * The current period keys in the couple's timezone (Decision 7). Reuses the
 * ADR-011 parity-pinned `localDayKey` (DST-correct by construction) — never a
 * re-implementation — and takes `monthKey` as its yyyymm prefix so the day and
 * month keys are derived from ONE zone projection and can never disagree. Throws
 * only on an invalid timezone (allow-listed at join, so effectively unreachable;
 * the service maps that defensively).
 */
export function computePeriodKeys(nowMs: number, timezone: string): PeriodKeys {
  const dayKey = localDayKey(new Date(nowMs), timezone);
  return { dayKey, monthKey: dayKey.slice(0, 6) };
}

/** The couple-shared monthly bucket state (parent doc). */
export interface MonthlyLane {
  monthKey: string;
  count: number;
}

/** The per-user daily lane state (self-read subcollection doc). */
export interface DailyLane {
  dayKey: string;
  count: number;
}

export type ReserveResult =
  | { kind: 'cap-exceeded'; which: 'cap-daily' | 'cap-monthly' }
  | {
      kind: 'reserved';
      newParent: MonthlyLane;
      newDaily: DailyLane;
      remaining: { daily: number; monthly: number };
    };

/**
 * The reserve decision (Decision 7), with LAZY key reset: a stored lane whose key
 * differs from the current period key is treated as count 0 (stale — no TTL, no
 * sweep). Then both caps are checked and, if clear, BOTH lanes increment. Order:
 * the per-user DAILY cap is checked first — it is the tighter, sooner-resetting,
 * user-controlled bound, and "come back tomorrow" is the actionable message for a
 * user who exhausted their own allotment. When both would exceed, `cap-daily`
 * wins (both are true statements; M5.2 renders daily vs monthly distinctly from
 * the frozen reason strings regardless).
 *
 * `remaining` is the point-in-time hint the response echoes; it is stale the
 * moment a partner reserves against the shared monthly bucket.
 */
export function planReserve(input: {
  parentMonthly: MonthlyLane | null;
  dailyLane: DailyLane | null;
  dayKey: string;
  monthKey: string;
  caps: CapConfig;
}): ReserveResult {
  const dailyCount =
    input.dailyLane !== null && input.dailyLane.dayKey === input.dayKey ? input.dailyLane.count : 0;
  const monthlyCount =
    input.parentMonthly !== null && input.parentMonthly.monthKey === input.monthKey
      ? input.parentMonthly.count
      : 0;

  if (dailyCount >= input.caps.dailyPerUser) {
    return { kind: 'cap-exceeded', which: 'cap-daily' };
  }
  if (monthlyCount >= input.caps.monthlyPerCouple) {
    return { kind: 'cap-exceeded', which: 'cap-monthly' };
  }

  const newDaily: DailyLane = { dayKey: input.dayKey, count: dailyCount + 1 };
  const newParent: MonthlyLane = { monthKey: input.monthKey, count: monthlyCount + 1 };
  return {
    kind: 'reserved',
    newParent,
    newDaily,
    remaining: {
      daily: input.caps.dailyPerUser - newDaily.count,
      monthly: input.caps.monthlyPerCouple - newParent.count,
    },
  };
}

/** One lane's refund instruction: write the decremented count, or write nothing. */
export type LaneRefund = { write: true; count: number } | { write: false };

export interface RefundPlan {
  daily: LaneRefund;
  monthly: LaneRefund;
}

/**
 * The refund decision (Decision 7): each lane decrements INDEPENDENTLY, guarded by
 * its OWN captured period key. A lane refunds iff its stored key still equals the
 * key the reserve wrote; on a mismatch it writes NOTHING to that lane (never a
 * lazy reset). This is why the guard is per-lane: a reserve at 23:59 refunded at
 * 00:01 crosses the daily boundary but not the monthly one — a single shared
 * guard would either corrupt the fresh day's count or skip a valid monthly refund.
 * Floor 0: a refund never drives a count negative.
 */
export function planRefund(input: {
  parentMonthly: MonthlyLane | null;
  dailyLane: DailyLane | null;
  reservedDayKey: string;
  reservedMonthKey: string;
}): RefundPlan {
  return {
    daily:
      input.dailyLane !== null && input.dailyLane.dayKey === input.reservedDayKey
        ? { write: true, count: Math.max(0, input.dailyLane.count - 1) }
        : { write: false },
    monthly:
      input.parentMonthly !== null && input.parentMonthly.monthKey === input.reservedMonthKey
        ? { write: true, count: Math.max(0, input.parentMonthly.count - 1) }
        : { write: false },
  };
}

// --- PII-safe logging (Decision 8) ------------------------------------------

/**
 * Every decision `coachProxy` can log. The two CRISIS outcomes (`crisis`
 * pre-scan, `help-path` post-filter) are metadata-minimized: their log line
 * carries only {outcome, language, latencyMs} — see logCoachEvent.
 */
export type CoachOutcome =
  | 'reply'
  | 'crisis'
  | 'help-path'
  | 'not-member'
  | 'not-premium'
  | 'cap-daily'
  | 'cap-monthly'
  | 'rate-limited'
  | 'unavailable'
  | 'invalid'
  | 'internal';

/** The crisis outcomes whose log line must omit coupleId/personaId (Decision 8). */
const CRISIS_OUTCOMES: ReadonlySet<CoachOutcome> = new Set<CoachOutcome>(['crisis', 'help-path']);

/**
 * The ONLY fields a coach log line may carry. There is deliberately NO `text` /
 * message field and NO `uid` field — the signature is the guarantee
 * (payload-policy precedent). `coupleId`/`personaId` are OPTIONAL because the
 * crisis outcomes drop them.
 */
export interface CoachEventLog {
  outcome: CoachOutcome;
  language: CoachLanguage;
  coupleId?: string;
  personaId?: CoachPersonaId;
  capRemainingDaily?: number;
  capRemainingMonthly?: number;
  latencyMs?: number;
  errorCode?: string;
}

/** The builder input — same fields; the builder decides what survives. */
export interface CoachEventInput {
  outcome: CoachOutcome;
  language: CoachLanguage;
  coupleId?: string;
  personaId?: CoachPersonaId;
  capRemainingDaily?: number;
  capRemainingMonthly?: number;
  latencyMs?: number;
  errorCode?: string;
}

/**
 * Projects a coach log line (Decision 8). For a CRISIS outcome the line is
 * reduced to {outcome, language, latencyMs?} — coupleId, personaId, cap counts
 * and errorCode are DROPPED even if supplied: "couple X tripped the self-harm
 * detector" is special-category-adjacent personal data under the KVKK/PDPL
 * posture, so ops can COUNT help-path hits but never attribute them. Every field
 * is a typed value; there is no path for message text or a uid to enter.
 */
export function logCoachEvent(input: CoachEventInput): CoachEventLog {
  const event: CoachEventLog = { outcome: input.outcome, language: input.language };
  if (!CRISIS_OUTCOMES.has(input.outcome)) {
    if (input.coupleId !== undefined) {
      event.coupleId = input.coupleId;
    }
    if (input.personaId !== undefined) {
      event.personaId = input.personaId;
    }
    if (input.capRemainingDaily !== undefined) {
      event.capRemainingDaily = input.capRemainingDaily;
    }
    if (input.capRemainingMonthly !== undefined) {
      event.capRemainingMonthly = input.capRemainingMonthly;
    }
    if (input.errorCode !== undefined) {
      event.errorCode = input.errorCode;
    }
  }
  if (input.latencyMs !== undefined) {
    event.latencyMs = input.latencyMs;
  }
  return event;
}
