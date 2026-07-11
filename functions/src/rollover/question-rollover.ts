// questionRollover — the M3.2 scheduled Function (ADR-011): a single hourly
// UTC sweep; runQuestionRollover buckets couples by stored timezone and
// creates each couple's days/{yyyymmdd} at its own local midnight,
// create-if-absent (idempotent, self-healing intra-day). Handler factory with
// injectable deps (the M2.x pattern: docs/architecture.md §2) so the closure
// is testable in-process — the CI emulator set has no scheduler, and the
// schedule trigger itself is deploy-verified later (Blaze item). No
// retryCount by design: the next hourly sweep IS the retry.
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { ScheduledEvent, onSchedule } from 'firebase-functions/v2/scheduler';

import { FUNCTIONS_REGION } from '../invites/create-invite';
import { FcmMessagingPort } from '../notifications/fcm-adapter';
import { AtRiskSummary, runStreakAtRisk } from '../notifications/at-risk';
import type { MessagingPort } from '../notifications/messaging-port';
import {
  CoupleBuckets,
  RolloverSummary,
  bucketCouplesByTimezone,
  runQuestionRollover,
} from './rollover-service';

const errorMessage = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

/** Every I/O dependency injectable; production uses the getFirestore()/FCM defaults. */
export interface QuestionRolloverDeps {
  /** THE single couples read + timezone bucketing, shared by both passes below. */
  bucket?: (db: Firestore) => Promise<CoupleBuckets>;
  /** The assignment pass over the shared buckets (create-if-absent day docs). */
  run?: (db: Firestore, at: Date, buckets: CoupleBuckets) => Promise<RolloverSummary>;
  /** The at-risk push pass over the shared buckets (hour-20, ADR-012 D3). */
  atRisk?: (
    db: Firestore,
    at: Date,
    buckets: CoupleBuckets,
    messaging: MessagingPort,
  ) => Promise<AtRiskSummary>;
  /** The push send seam (FCM has no emulator, so tests inject a fake — ADR-012 D3). */
  messaging?: MessagingPort;
  now?: () => Date;
}

export function makeQuestionRolloverHandler(
  deps: QuestionRolloverDeps = {},
): (event: ScheduledEvent) => Promise<void> {
  const {
    bucket = bucketCouplesByTimezone,
    // runQuestionRollover's 3rd arg is loadPack (default when undefined); the shared
    // buckets go in the 4th. atRisk forwards the injected messaging port.
    run = (db, at, buckets) => runQuestionRollover(db, at, undefined, buckets),
    atRisk = (db, at, buckets, messaging) => runStreakAtRisk(db, at, messaging, buckets),
    messaging = new FcmMessagingPort(),
    now = () => new Date(),
  } = deps;
  return async (event) => {
    // The nominal scheduled instant beats the wall clock (no early-fire
    // skew), but a manual/emulator trigger can deliver a missing or garbage
    // scheduleTime — new Date() then yields Invalid Date, which would throw
    // inside Intl for EVERY bucket. Validate and fall back loudly.
    const parsed = new Date(event.scheduleTime);
    const validScheduleTime = !Number.isNaN(parsed.getTime());
    if (!validScheduleTime) {
      logger.warn('question_rollover: unparseable scheduleTime, using wall clock', {
        scheduleTime: event.scheduleTime,
      });
    }
    const at = validScheduleTime ? parsed : now();
    const db = getFirestore();

    // THE single couples read of the whole sweep (ADR-012 D3 hard constraint): the
    // timezone bucketing is computed ONCE and threaded into both passes below, so
    // the streak-at-risk check adds zero couples reads. Failing to even LIST the
    // couples is systemic — throw, marking the run failed, as the M3.2 sweep did.
    let buckets: CoupleBuckets;
    try {
      buckets = await bucket(db);
    } catch (error) {
      logger.error('question_rollover: sweep failed', { at: at.toISOString(), error: errorMessage(error) });
      throw error;
    }

    // Assignment pass. Per-couple problems are handled (and logged) inside; only a
    // systemic failure reaches here and must mark the run failed (unchanged M3.2).
    let summary: RolloverSummary;
    try {
      summary = await run(db, at, buckets);
      logger.info('question_rollover: sweep complete', { at: at.toISOString(), ...summary });
    } catch (error) {
      logger.error('question_rollover: sweep failed', { at: at.toISOString(), error: errorMessage(error) });
      throw error;
    }

    // At-risk push pass (ADR-012 D3, piggybacked): fully ISOLATED and best-effort —
    // a failure here must never fail the assignment run (a missed nudge is recovered
    // next day; an unassigned question is not). Per-couple/per-send failures are
    // logged+counted inside; a systemic throw is swallowed with a loud log.
    try {
      const atRiskSummary = await atRisk(db, at, buckets, messaging);
      logger.info('question_rollover: at-risk sweep complete', { at: at.toISOString(), ...atRiskSummary });
    } catch (error) {
      logger.error('question_rollover: at-risk sweep failed (isolated from assignment)', {
        at: at.toISOString(),
        error: errorMessage(error),
      });
    }
  };
}

export const questionRollover = onSchedule(
  {
    region: FUNCTIONS_REGION,
    // Hourly at :00 UTC; each run computes which couples just crossed THEIR
    // local midnight (sub-hour-offset zones land on the first run after it).
    schedule: '0 * * * *',
    timeZone: 'Etc/UTC',
    // Explicit ceilings (ADR-011): the sweep is sequential per couple, so
    // wall-clock — not read cost — is the binding constraint at scale.
    timeoutSeconds: 120,
    memory: '256MiB',
  },
  makeQuestionRolloverHandler(),
);
