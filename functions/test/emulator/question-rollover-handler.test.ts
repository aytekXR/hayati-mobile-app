// In-process tests for the questionRollover scheduled handler (M3.2). The CI
// emulator set has no scheduler, so the handler closure is driven directly
// (the M2.x create-invite-handler idiom); the schedule trigger itself is
// deploy-verified later (Blaze item, docs/operator-expected.md). These prove
// the acceptance criteria at the SCHEDULED-HANDLER level: assignment in each
// couple's own local date and double-run idempotency.
import { Timestamp } from 'firebase-admin/firestore';
import type { ScheduledEvent } from 'firebase-functions/v2/scheduler';
import { beforeEach, describe, expect, it } from 'vitest';

import { makeQuestionRolloverHandler } from '../../src/rollover/question-rollover';
import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();
const couples = db.collection('couples');

// Same acceptance instant as the service suite: 2026-07-10 in Istanbul,
// still 2026-07-09 in New York.
const SCHEDULE_TIME = '2026-07-10T02:00:00Z';

function scheduledEvent(scheduleTime: string | undefined): ScheduledEvent {
  return { jobName: 'test-job', scheduleTime } as ScheduledEvent;
}

function seedCouple(coupleId: string, timezone: string): Promise<FirebaseFirestore.WriteResult> {
  return couples.doc(coupleId).set({
    memberUids: ['uid-a', 'uid-b'],
    timezone,
    createdAt: Timestamp.now(),
  });
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('makeQuestionRolloverHandler', () => {
  it('sweeps the fleet on the scheduled instant, each couple in its own local date', async () => {
    await seedCouple('ist', 'Europe/Istanbul');
    await seedCouple('nyc', 'America/New_York');

    // Default deps on purpose: real sweep + bundled default pack end-to-end.
    await makeQuestionRolloverHandler()(scheduledEvent(SCHEDULE_TIME));

    const ist = await couples.doc('ist').collection('days').doc('20260710').get();
    const nyc = await couples.doc('nyc').collection('days').doc('20260709').get();
    expect(ist.exists).toBe(true);
    expect(nyc.exists).toBe(true);
    expect(ist.data()!.questionId).toBe('solo_tr_001');
    expect(nyc.data()!.questionId).toBe('solo_tr_001');
  });

  it('is idempotent when the same scheduled hour is delivered twice', async () => {
    await seedCouple('ist', 'Europe/Istanbul');
    const handler = makeQuestionRolloverHandler();

    await handler(scheduledEvent(SCHEDULE_TIME));
    const first = (await couples.doc('ist').collection('days').doc('20260710').get()).data()!;

    await handler(scheduledEvent(SCHEDULE_TIME));
    const days = await couples.doc('ist').collection('days').get();
    expect(days.size).toBe(1);
    expect(days.docs[0].data()).toEqual(first);
  });

  it('falls back to the injected clock when scheduleTime is unparseable', async () => {
    await seedCouple('ist', 'Europe/Istanbul');
    const handler = makeQuestionRolloverHandler({ now: () => new Date(SCHEDULE_TIME) });

    await handler(scheduledEvent('not-a-timestamp'));

    const doc = await couples.doc('ist').collection('days').doc('20260710').get();
    expect(doc.exists).toBe(true);
  });

  it('falls back to the injected clock when scheduleTime is absent (manual trigger)', async () => {
    await seedCouple('ist', 'Europe/Istanbul');
    const handler = makeQuestionRolloverHandler({ now: () => new Date(SCHEDULE_TIME) });

    await handler(scheduledEvent(undefined));

    const doc = await couples.doc('ist').collection('days').doc('20260710').get();
    expect(doc.exists).toBe(true);
  });

  it('lets systemic sweep failures escape so the run is marked failed', async () => {
    const handler = makeQuestionRolloverHandler({
      run: async () => {
        throw new Error('firestore unavailable');
      },
    });
    await expect(handler(scheduledEvent(SCHEDULE_TIME))).rejects.toThrow('firestore unavailable');
  });
});
