// M3.2 rollover service (ADR-011): assigns each couple its day's question by
// creating couples/{cid}/days/{yyyymmdd}. Two layers, both taking an injected
// Firestore (the M2.x service idiom):
//   - assignDayQuestion: one couple, one dayKey. Create-if-absent — an
//     existing day doc is NEVER reassigned or rewritten, and losing the
//     create race to an overlapping sweep is a benign 'exists' (selection is
//     deterministic, so the racer computed the same assignment; only today's
//     dayKey is ever written, which is what makes the non-transactional
//     read-then-create safe — do not add older-day backfill without
//     revisiting ADR-011).
//   - runQuestionRollover: the hourly sweep. Groups couples by their STORED
//     timezone (the bucket), computes each bucket's local calendar date once,
//     and assigns per couple. Per-couple problems (malformed packConfig,
//     missing/corrupt timezone, unloadable pack) are logged skips counted in
//     the summary — never a failed run: one poisoned couple must not paint
//     every hourly sweep red. The stored timezone is used VERBATIM — no
//     silent re-resolution to a default; corrupt state must surface.
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { localDayKey } from './day-key';
import { QuestionPack, loadQuestionPack } from './pack-loader';
import { selectQuestion } from './select-question';

/**
 * Placeholder couple bank until W9 authors the real couple packs
 * (tr_playful/tr_respectful/ar_msa_gulf/en): the register-neutral TR solo
 * pack, mirroring the DEFAULT_COUPLE_TIMEZONE personal-use-first precedent
 * (ADR-007, ADR-011 decision 3).
 */
export const DEFAULT_PACK_ID = 'solo_tr';

/** Loads a pack by id; sync (bundled fs read) or async both supported. */
export type PackLoader = (packId: string) => QuestionPack | Promise<QuestionPack>;

/** A couple doc whose fields cannot drive an assignment (never a silent fallback). */
export class InvalidCoupleError extends Error {
  constructor(coupleId: string, detail: string) {
    super(`couple ${coupleId}: ${detail}`);
    this.name = 'InvalidCoupleError';
  }
}

export interface RolloverSummary {
  /** Day docs created this run. */
  assigned: number;
  /** Couples whose day doc already existed (idempotent re-run/overlap). */
  existing: number;
  /** Couples skipped on a per-couple error (also logged individually). */
  failed: number;
  failedCoupleIds: string[];
  /** Distinct timezones seen this run. */
  buckets: number;
}

// gRPC status ALREADY_EXISTS (google.rpc.Code 6): DocumentReference.create()
// rejects with a numeric-code GoogleError when the doc exists. Never match on
// message or string codes — other Firebase products use 'already-exists'.
const GRPC_ALREADY_EXISTS = 6;

/** True only for the numeric gRPC ALREADY_EXISTS create-conflict. */
export function isAlreadyExists(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    (error as { code?: unknown }).code === GRPC_ALREADY_EXISTS
  );
}

/**
 * The couple's configured packId: absent packConfig falls back to
 * DEFAULT_PACK_ID; a PRESENT but malformed packConfig throws — presence with
 * junk must not masquerade as the default (ADR-011 decision 3).
 */
export function resolvePackId(coupleId: string, data: FirebaseFirestore.DocumentData): string {
  if (!('packConfig' in data)) {
    return DEFAULT_PACK_ID;
  }
  const packConfig: unknown = data.packConfig;
  if (typeof packConfig !== 'object' || packConfig === null || Array.isArray(packConfig)) {
    throw new InvalidCoupleError(coupleId, 'malformed packConfig (not an object)');
  }
  const packId: unknown = (packConfig as Record<string, unknown>).packId;
  if (typeof packId !== 'string' || packId.length === 0) {
    throw new InvalidCoupleError(coupleId, 'malformed packConfig (packId not a non-empty string)');
  }
  return packId;
}

/** The couple's stored IANA timezone, verbatim; missing/non-string throws. */
export function coupleTimezone(coupleId: string, data: FirebaseFirestore.DocumentData): string {
  const timezone: unknown = data.timezone;
  if (typeof timezone !== 'string' || timezone.length === 0) {
    throw new InvalidCoupleError(coupleId, 'missing timezone');
  }
  return timezone;
}

/**
 * Creates couples/{coupleId}/days/{dayKey} with the day's question if absent.
 * History = a questionId projection over the days subcollection (O(history)
 * reads, ADR-011 cost note); docs without a string questionId are ignored so
 * a foreign-shape doc cannot corrupt selection.
 */
export async function assignDayQuestion(
  db: Firestore,
  coupleId: string,
  dayKey: string,
  packId: string,
  loadPack: PackLoader = loadQuestionPack,
): Promise<'created' | 'exists'> {
  const dayRef = db.collection('couples').doc(coupleId).collection('days').doc(dayKey);
  const existing = await dayRef.get();
  if (existing.exists) {
    return 'exists';
  }

  const pack = await loadPack(packId);
  const history = await dayRef.parent.select('questionId').get();
  const historyIds = history.docs
    .map((doc) => doc.get('questionId') as unknown)
    .filter((id): id is string => typeof id === 'string');
  const question = selectQuestion(pack, historyIds);

  try {
    await dayRef.create({
      questionId: question.id,
      packId: pack.packId,
      packVersion: pack.version,
      assignedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (isAlreadyExists(error)) {
      // An overlapping run won the race after our existence check; its
      // assignment is the same deterministic selection — nothing to do.
      return 'exists';
    }
    throw error;
  }
  return 'created';
}

/**
 * One sweep over all couples for the instant `at` (the scheduled hour):
 * bucket by stored timezone, compute each bucket's local date once, assign
 * create-if-absent. Throws only on systemic failure (e.g. couples
 * unlistable); per-couple errors are logged skips in the summary.
 */
export async function runQuestionRollover(
  db: Firestore,
  at: Date,
  loadPack: PackLoader = loadQuestionPack,
): Promise<RolloverSummary> {
  const summary: RolloverSummary = {
    assigned: 0,
    existing: 0,
    failed: 0,
    failedCoupleIds: [],
    buckets: 0,
  };
  const skip = (coupleId: string, error: unknown): void => {
    summary.failed += 1;
    summary.failedCoupleIds.push(coupleId);
    logger.error('question_rollover: couple skipped', {
      coupleId,
      error: error instanceof Error ? error.message : String(error),
    });
  };

  const couples = await db.collection('couples').get();
  const buckets = new Map<string, { coupleId: string; packId: string }[]>();
  for (const doc of couples.docs) {
    try {
      const timezone = coupleTimezone(doc.id, doc.data());
      const packId = resolvePackId(doc.id, doc.data());
      const bucket = buckets.get(timezone) ?? [];
      bucket.push({ coupleId: doc.id, packId });
      buckets.set(timezone, bucket);
    } catch (error) {
      skip(doc.id, error);
    }
  }
  summary.buckets = buckets.size;

  for (const [timezone, members] of buckets) {
    let dayKey: string;
    try {
      dayKey = localDayKey(at, timezone);
    } catch (error) {
      // Non-IANA stored zone: every couple in the bucket is corrupt state.
      for (const member of members) {
        skip(member.coupleId, error);
      }
      continue;
    }
    for (const member of members) {
      try {
        const status = await assignDayQuestion(db, member.coupleId, dayKey, member.packId, loadPack);
        if (status === 'created') {
          summary.assigned += 1;
        } else {
          summary.existing += 1;
        }
      } catch (error) {
        skip(member.coupleId, error);
      }
    }
  }
  return summary;
}
