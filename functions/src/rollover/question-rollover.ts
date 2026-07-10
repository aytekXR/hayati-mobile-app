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
import { RolloverSummary, runQuestionRollover } from './rollover-service';

/** Every I/O dependency injectable; production uses the defaults. */
export interface QuestionRolloverDeps {
  run?: (db: Firestore, at: Date) => Promise<RolloverSummary>;
  now?: () => Date;
}

export function makeQuestionRolloverHandler(
  deps: QuestionRolloverDeps = {},
): (event: ScheduledEvent) => Promise<void> {
  const { run = runQuestionRollover, now = () => new Date() } = deps;
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

    try {
      const summary = await run(getFirestore(), at);
      logger.info('question_rollover: sweep complete', {
        at: at.toISOString(),
        ...summary,
      });
    } catch (error) {
      // Per-couple problems are handled (and logged) inside the sweep; only
      // systemic failures reach here and must mark the run failed.
      logger.error('question_rollover: sweep failed', {
        at: at.toISOString(),
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
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
