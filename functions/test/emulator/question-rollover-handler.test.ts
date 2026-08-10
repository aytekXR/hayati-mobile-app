// In-process tests for the questionRollover scheduled handler (M3.2). The CI
// emulator set has no scheduler, so the handler closure is driven directly
// (the M2.x create-invite-handler idiom); the schedule trigger itself is
// deploy-verified later (Blaze item, docs/operator-expected.md). These prove
// the acceptance criteria at the SCHEDULED-HANDLER level: assignment in each
// couple's own local date and double-run idempotency.
import { Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import type { ScheduledEvent } from 'firebase-functions/v2/scheduler';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { makeQuestionRolloverHandler } from '../../src/rollover/question-rollover';
import { adminFirestore, clearFirestoreData } from '../support/admin';
import { FakeMessagingPort } from '../support/fake-messaging-port';

// SCHEDULE_TIME (02:00Z, 05:00 local) is off-hour, so the ordinary sweeps above
// never trip either push pass.
// 19:00Z is 22:00 in Europe/Istanbul — the nudge hour since ADR-045 (was 16 under
// ADR-042 D4, and 20 before that). 22 is the LAST hour before the 23:00 quiet
// window, which moved in the same change so this push could exist at all.
const AT_RISK_TIME = '2026-07-10T19:00:00Z';
// 06:00Z is 09:00 in Europe/Istanbul — the daily-question hour since ADR-045
// (was 08:00 under ADR-042 D3). Only the ANNOUNCEMENT moved; rollover still
// assigns at local midnight.
const DAILY_QUESTION_TIME = '2026-07-10T06:00:00Z';

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

  it('lets a systemic bucketing failure (couples unlistable) escape and mark the run failed', async () => {
    const handler = makeQuestionRolloverHandler({
      bucket: async () => {
        throw new Error('couples unlistable');
      },
    });
    await expect(handler(scheduledEvent(SCHEDULE_TIME))).rejects.toThrow('couples unlistable');
  });

  it('drives all three passes off ONE couples read: logs every summary, and nudges at hour 22', async () => {
    // A couple mid-streak with today's day doc still unrevealed and no answers yet
    // → both members are at-risk recipients. No answer docs are seeded, so the live
    // answerReveal trigger never fires here.
    await couples.doc('ist').set({
      memberUids: ['uid-a', 'uid-b'],
      timezone: 'Europe/Istanbul',
      createdAt: Timestamp.now(),
      streak: { count: 3, lastMutualDate: '20260709', graceTokens: 1 },
    });
    await couples.doc('ist').collection('days').doc('20260710').set({
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
    });
    await db.collection('users').doc('uid-a').set({ contentLanguage: 'en', fcmTokens: ['tok-a'] });
    await db.collection('users').doc('uid-b').set({ contentLanguage: 'en', fcmTokens: ['tok-b'] });

    const port = new FakeMessagingPort();
    const infoSpy = vi.spyOn(logger, 'info');
    const handler = makeQuestionRolloverHandler({ messaging: port });

    await handler(scheduledEvent(AT_RISK_TIME));

    // Both members nudged, and BOTH summaries were logged (assignment + at-risk).
    expect(port.sent.map((m) => m.token).sort()).toEqual(['tok-a', 'tok-b']);
    expect(infoSpy).toHaveBeenCalledWith(
      'question_rollover: sweep complete',
      expect.objectContaining({ existing: 1 }),
    );
    expect(infoSpy).toHaveBeenCalledWith(
      'question_rollover: at-risk sweep complete',
      expect.objectContaining({ checked: 1, sent: 2 }),
    );
    // The daily-question pass ran too and found nothing to do at 22:00 — ADR-012
    // D3's ONE couples read is shared by all three, so a pass with no work still
    // logs its summary.
    expect(infoSpy).toHaveBeenCalledWith(
      'question_rollover: daily-question sweep complete',
      expect.objectContaining({ checked: 0, sent: 0 }),
    );
    infoSpy.mockRestore();
  });

  // ADR-042 D3. Same shared buckets, different hour, different kind.
  it('announces the daily question at hour 9, off the SAME single couples read', async () => {
    await couples.doc('ist').set({
      memberUids: ['uid-a', 'uid-b'],
      timezone: 'Europe/Istanbul',
      createdAt: Timestamp.now(),
    });
    await couples.doc('ist').collection('days').doc('20260710').set({
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
    });
    await db.collection('users').doc('uid-a').set({ contentLanguage: 'en', fcmTokens: ['tok-a'] });
    await db.collection('users').doc('uid-b').set({ contentLanguage: 'en', fcmTokens: ['tok-b'] });

    const port = new FakeMessagingPort();
    const infoSpy = vi.spyOn(logger, 'info');
    const handler = makeQuestionRolloverHandler({ messaging: port });

    await handler(scheduledEvent(DAILY_QUESTION_TIME));

    expect(port.sent.map((m) => m.token).sort()).toEqual(['tok-a', 'tok-b']);
    expect(infoSpy).toHaveBeenCalledWith(
      'question_rollover: daily-question sweep complete',
      expect.objectContaining({ checked: 1, sent: 2 }),
    );
    // And the nudge pass, sharing the same buckets, correctly did nothing at 09:00.
    expect(infoSpy).toHaveBeenCalledWith(
      'question_rollover: at-risk sweep complete',
      expect.objectContaining({ checked: 0, sent: 0 }),
    );
    infoSpy.mockRestore();
  });

  it('isolates a daily-question failure from BOTH the assignment run and the nudge pass', async () => {
    await seedCouple('ist', 'Europe/Istanbul');
    const errorSpy = vi.spyOn(logger, 'error');
    const infoSpy = vi.spyOn(logger, 'info');
    const handler = makeQuestionRolloverHandler({
      dailyQuestion: async () => {
        throw new Error('daily boom');
      },
    });

    await expect(handler(scheduledEvent(DAILY_QUESTION_TIME))).resolves.toBeUndefined();
    expect((await couples.doc('ist').collection('days').doc('20260710').get()).exists).toBe(true);
    expect(errorSpy).toHaveBeenCalledWith(
      'question_rollover: daily-question sweep failed (isolated)',
      expect.objectContaining({ error: 'daily boom' }),
    );
    // The nudge pass still ran — one push pass throwing must not silence the other.
    expect(infoSpy).toHaveBeenCalledWith(
      'question_rollover: at-risk sweep complete',
      expect.anything(),
    );
    errorSpy.mockRestore();
    infoSpy.mockRestore();
  });

  it('isolates an at-risk pass failure from the assignment run (assignment commits, handler does not reject)', async () => {
    await seedCouple('ist', 'Europe/Istanbul');
    const errorSpy = vi.spyOn(logger, 'error');
    const handler = makeQuestionRolloverHandler({
      atRisk: async () => {
        throw new Error('at-risk boom');
      },
    });

    // The at-risk throw is swallowed — the handler resolves and the assignment
    // still committed today's day doc.
    await expect(handler(scheduledEvent(AT_RISK_TIME))).resolves.toBeUndefined();
    expect((await couples.doc('ist').collection('days').doc('20260710').get()).exists).toBe(true);
    expect(errorSpy).toHaveBeenCalledWith(
      'question_rollover: at-risk sweep failed (isolated from assignment)',
      expect.objectContaining({ error: 'at-risk boom' }),
    );
    errorSpy.mockRestore();
  });
});
