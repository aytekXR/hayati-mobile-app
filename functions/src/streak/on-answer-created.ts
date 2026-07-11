// answerReveal — the repo's FIRST Firestore trigger (ADR-012 Decision 1):
// onDocumentCreated on couples/{coupleId}/days/{dayKey}/answers/{authorUid}.
// The reveal condition ("both answer docs exist") can only BECOME true at the
// CREATE of the second answer — post-reveal docs are immutable (M3.3 rules) and
// a pre-reveal typo edit never changes existence — so onDocumentCreated, not
// onDocumentWritten. Handler factory with injectable deps (the M2.x /
// makeQuestionRolloverHandler mold) so the closure is testable in-process: the
// CI emulator delivers the trigger too, but the acceptance is carried by the
// in-process handleAnswerCreated suites, and the wire itself is a thin e2e /
// deploy-verified (same posture as the rollover schedule trigger).
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { FirestoreEvent, QueryDocumentSnapshot, onDocumentCreated } from 'firebase-functions/v2/firestore';

import { FUNCTIONS_REGION } from '../invites/create-invite';
import { FcmMessagingPort } from '../notifications/fcm-adapter';
import type { MessagingPort } from '../notifications/messaging-port';
import { HandleAnswerCreatedOutcome, RevealServiceDeps, handleAnswerCreated } from './reveal-service';

/** The params the {coupleId}/{dayKey}/{authorUid} document pattern binds. */
type AnswerParams = { coupleId: string; dayKey: string; authorUid: string };

/** Every I/O dependency injectable; production uses the getFirestore()/FCM defaults. */
export interface OnAnswerCreatedDeps extends RevealServiceDeps {
  handle?: typeof handleAnswerCreated;
  messaging?: MessagingPort;
}

export function makeOnAnswerCreatedHandler(
  deps: OnAnswerCreatedDeps = {},
): (event: FirestoreEvent<QueryDocumentSnapshot | undefined, AnswerParams>) => Promise<void> {
  const { handle = handleAnswerCreated, messaging = new FcmMessagingPort(), now, beforeWrite } = deps;
  return async (event) => {
    const { coupleId, dayKey, authorUid } = event.params;
    // Defense in depth: a malformed event with missing/garbage params must not
    // reach the transaction (getFirestore().doc() would throw on an empty path
    // segment) — surface it as a logged skip, never a throw that retry-loops.
    if (!coupleId || !dayKey || !authorUid) {
      logger.error('answer_reveal: dropping event with missing path params', {
        coupleId,
        dayKey,
        authorUid,
      });
      return;
    }

    try {
      const outcome: HandleAnswerCreatedOutcome = await handle(
        getFirestore(),
        messaging,
        { coupleId, dayKey, authorUid },
        { now, beforeWrite },
      );
      logger.info('answer_reveal: trigger complete', {
        coupleId,
        dayKey,
        authorUid,
        decision: outcome.decision,
        skipReason: outcome.skipReason,
        streakApplied: outcome.streakApplied,
      });
    } catch (error) {
      // handleAnswerCreated returns a typed skip for every corrupt/absent state,
      // so only a genuinely systemic failure (e.g. Firestore unavailable) reaches
      // here; log it and rethrow so the retry:true registration below gets a
      // redelivery — the idempotent latch makes the re-drive safe, and without
      // the rethrow-plus-retry pair the mutual day would be silently lost.
      logger.error('answer_reveal: trigger failed', {
        coupleId,
        dayKey,
        authorUid,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  };
}

export const answerReveal = onDocumentCreated(
  {
    region: FUNCTIONS_REGION,
    document: 'couples/{coupleId}/days/{dayKey}/answers/{authorUid}',
    // retry:true is LOAD-BEARING (Session 014 review finding): without it a
    // systemic failure (Firestore transiently unavailable, transaction aborted
    // past its internal retries) is acked-and-dropped — and since both answer
    // docs are immutable post-reveal (M3.3 rules) no create event ever fires
    // again for this day, so the mutual day would be lost FOREVER and poison
    // the next applyMutualDay as a phantom missed day. Redelivery is safe by
    // construction: data-shape problems return typed skips (never throw, so
    // they can't loop), the revealedAt latch makes the transaction idempotent,
    // and pushes are emitted only by the invocation whose transaction commits.
    retry: true,
    // Explicit ceilings: one transaction over a handful of docs plus one
    // best-effort send — tiny work, but pin the wall-clock and memory so a
    // misbehaving send can never run unbounded (the transactional invariant
    // holds regardless of push timing, ADR-012 D1).
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  makeOnAnswerCreatedHandler(),
);
