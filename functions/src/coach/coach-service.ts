// The Firestore half of the M5.1 coach caps (ADR-016 Decision 6/7). `db` is the
// FIRST param and the ONLY Firestore handle — no getFirestore() here; the proxy
// shell resolves it and injects it (the entitlement-service mold). Every decidable
// state is a TYPED outcome, never a throw (the ProcessOutcome discipline): the one
// consistent read set (couples membership → subscriptions mirror → the two cap
// lanes) is checked and, if clear, BOTH lanes reserve inside a single transaction
// BEFORE the provider call — the concurrency latch that closes the parallel-read
// cost hole. Refund is a best-effort second transaction, per-lane captured-key
// guarded, that NEVER throws. The WHAT (arithmetic, key derivation, PII-safe log
// shape) lives in coach-core.ts; this module owns the transaction.
import { FieldValue, Firestore } from 'firebase-admin/firestore';

import { isPremiumMirror } from '../entitlements/entitlement-core';
import {
  CapConfig,
  DailyLane,
  MonthlyLane,
  computePeriodKeys,
  planRefund,
  planReserve,
} from './coach-core';

/**
 * The reserve decision as a typed union (Decision 2/7). Decidable states —
 * not-member, not-premium, cap-exceeded, internal — NEVER throw; the shell maps
 * each to a static-message HttpsError. `reserved` carries the point-in-time
 * `remaining` hint AND the two period keys the reserve WROTE, so a later refund
 * can guard each lane by its own captured key.
 */
export type ReserveOutcome =
  | { kind: 'not-member' }
  | { kind: 'not-premium' }
  | { kind: 'cap-exceeded'; which: 'cap-daily' | 'cap-monthly' }
  | { kind: 'internal' }
  | {
      kind: 'reserved';
      remaining: { daily: number; monthly: number };
      reservedDayKey: string;
      reservedMonthKey: string;
    };

/** The refund outcome (Decision 7): which lanes were written, or a swallowed failure. */
export type RefundOutcome =
  | { kind: 'refunded'; daily: boolean; monthly: boolean }
  | { kind: 'refund-failed' };

export interface ReserveInput {
  coupleId: string;
  uid: string;
  nowMs: number;
  caps: CapConfig;
}

export interface RefundInput {
  coupleId: string;
  uid: string;
  reservedDayKey: string;
  reservedMonthKey: string;
}

/** The couple-shared monthly lane off the parent doc, or null if absent/malformed. */
function readMonthly(snap: FirebaseFirestore.DocumentSnapshot): MonthlyLane | null {
  if (!snap.exists) {
    return null;
  }
  const monthly = snap.get('monthly');
  if (
    monthly !== null &&
    typeof monthly === 'object' &&
    typeof (monthly as { monthKey?: unknown }).monthKey === 'string' &&
    typeof (monthly as { count?: unknown }).count === 'number'
  ) {
    const m = monthly as { monthKey: string; count: number };
    return { monthKey: m.monthKey, count: m.count };
  }
  return null;
}

/** The caller's per-user daily lane, or null if absent/malformed. */
function readDaily(snap: FirebaseFirestore.DocumentSnapshot): DailyLane | null {
  if (!snap.exists) {
    return null;
  }
  const dayKey = snap.get('dayKey');
  const count = snap.get('count');
  if (typeof dayKey === 'string' && typeof count === 'number') {
    return { dayKey, count };
  }
  return null;
}

/**
 * Reserves one coach turn against the couple's caps in ONE transaction (Decision
 * 7). The read set is fixed and membership resolves FIRST — an absent couple doc
 * or a non-member uid is a typed `not-member`, BEFORE any premium check, cap read,
 * or key derivation, so nothing about the couple's state leaks to a non-member and
 * no TOCTOU window exists. Then the mirror gates premium (Decision 6), the couple
 * timezone derives the period keys (an invalid zone — allow-listed at join, so
 * effectively unreachable — is defensively mapped to `internal`, never a raw
 * throw), and `planReserve` decides. On `reserved`, BOTH lanes are written with a
 * server-stamped `updatedAt`; every decidable state returns without a write.
 */
export async function reserveCoachTurn(db: Firestore, input: ReserveInput): Promise<ReserveOutcome> {
  const coupleRef = db.collection('couples').doc(input.coupleId);
  const subRef = db.collection('subscriptions').doc(input.coupleId);
  const parentRef = db.collection('coachUsage').doc(input.coupleId);
  const dailyRef = parentRef.collection('daily').doc(input.uid);

  return db.runTransaction<ReserveOutcome>(async (tx) => {
    // (a) Membership FIRST — from the in-transaction read, never a pre-read.
    const coupleSnap = await tx.get(coupleRef);
    if (!coupleSnap.exists) {
      return { kind: 'not-member' };
    }
    const memberUids = coupleSnap.get('memberUids');
    if (!Array.isArray(memberUids) || !memberUids.includes(input.uid)) {
      return { kind: 'not-member' };
    }

    // (b) Premium gate off the mirror (ADR-013 D5, one shared helper). Absent doc
    // → free tier → not premium; entitled:true + past expiry → not premium.
    const subSnap = await tx.get(subRef);
    const entitled = subSnap.exists && subSnap.get('entitled') === true;
    const rawExpiry = subSnap.exists ? subSnap.get('expiresAtMs') : null;
    const expiresAtMs = typeof rawExpiry === 'number' ? rawExpiry : null;
    if (!isPremiumMirror({ entitled, expiresAtMs }, input.nowMs)) {
      return { kind: 'not-premium' };
    }

    // (c) Period keys in the couple timezone. A malformed/junk zone throws out of
    // Intl — defensively mapped to `internal` (Decision 2), never a raw escape.
    const timezone = coupleSnap.get('timezone');
    let dayKey: string;
    let monthKey: string;
    try {
      const keys = computePeriodKeys(input.nowMs, typeof timezone === 'string' ? timezone : '');
      dayKey = keys.dayKey;
      monthKey = keys.monthKey;
    } catch {
      return { kind: 'internal' };
    }

    // (d) Cap reservation over both lanes (lazy key reset lives in planReserve).
    const parentSnap = await tx.get(parentRef);
    const dailySnap = await tx.get(dailyRef);
    const reserved = planReserve({
      parentMonthly: readMonthly(parentSnap),
      dailyLane: readDaily(dailySnap),
      dayKey,
      monthKey,
      caps: input.caps,
    });
    if (reserved.kind === 'cap-exceeded') {
      return { kind: 'cap-exceeded', which: reserved.which };
    }

    // Reserved: write both lanes (couple-shared monthly + self-read daily).
    tx.set(parentRef, { monthly: reserved.newParent, updatedAt: FieldValue.serverTimestamp() });
    tx.set(dailyRef, {
      dayKey: reserved.newDaily.dayKey,
      count: reserved.newDaily.count,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {
      kind: 'reserved',
      remaining: reserved.remaining,
      reservedDayKey: dayKey,
      reservedMonthKey: monthKey,
    };
  });
}

/**
 * Best-effort refund of a reserved turn on provider failure (Decision 2/7). A
 * SECOND transaction, per-lane guarded by its OWN captured key (planRefund): the
 * daily lane decrements iff its stored `dayKey` still equals `reservedDayKey`, the
 * monthly lane iff its stored `monthKey` equals `reservedMonthKey`; on a mismatch
 * (a period rollover between reserve and refund) it writes NOTHING to that lane.
 * NEVER throws — a refund failure leaves the units burned (logged by the shell,
 * typed fields only) and returns `refund-failed`, the accepted trade-off.
 */
export async function refundCoachTurn(db: Firestore, input: RefundInput): Promise<RefundOutcome> {
  const parentRef = db.collection('coachUsage').doc(input.coupleId);
  const dailyRef = parentRef.collection('daily').doc(input.uid);

  try {
    let daily = false;
    let monthly = false;
    await db.runTransaction(async (tx) => {
      const parentSnap = await tx.get(parentRef);
      const dailySnap = await tx.get(dailyRef);
      const plan = planRefund({
        parentMonthly: readMonthly(parentSnap),
        dailyLane: readDaily(dailySnap),
        reservedDayKey: input.reservedDayKey,
        reservedMonthKey: input.reservedMonthKey,
      });
      // Re-seed per attempt: the callback re-runs under contention.
      daily = plan.daily.write;
      monthly = plan.monthly.write;
      if (plan.daily.write) {
        tx.set(dailyRef, {
          dayKey: input.reservedDayKey,
          count: plan.daily.count,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      if (plan.monthly.write) {
        tx.set(parentRef, {
          monthly: { monthKey: input.reservedMonthKey, count: plan.monthly.count },
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    return { kind: 'refunded', daily, monthly };
  } catch {
    return { kind: 'refund-failed' };
  }
}
