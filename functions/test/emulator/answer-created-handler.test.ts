// In-process tests for the answerReveal trigger handler (M3.4, ADR-012 D1). The
// CI emulator DOES deliver Firestore triggers, but the acceptance lives in the
// reveal-service suite (the M3.2 handler idiom); these prove the thin handler
// contract: params → service drive, and the defense against a malformed event
// (missing/garbage path params must be a logged drop, never a throw-loop).
import { Timestamp } from 'firebase-admin/firestore';
import type { FirestoreEvent, QueryDocumentSnapshot } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { makeOnAnswerCreatedHandler } from '../../src/streak/on-answer-created';
import type { HandleAnswerCreatedOutcome } from '../../src/streak/reveal-service';
import { handleAnswerCreated } from '../../src/streak/reveal-service';
import { adminFirestore, clearFirestoreData } from '../support/admin';
import { FakeMessagingPort } from '../support/fake-messaging-port';

const db = adminFirestore();
const couples = db.collection('couples');

const CID = 'couple-1';
const UID_A = 'uid-a';
const UID_B = 'uid-b';
const DAY_KEY = '20260710';
const NOON = new Date('2026-07-10T09:00:00Z'); // Istanbul 12:00 (not quiet)

type AnswerParams = { coupleId: string; dayKey: string; authorUid: string };

/** A minimal FirestoreEvent — the handler only reads event.params. */
function answerEvent(params: Partial<AnswerParams>): FirestoreEvent<QueryDocumentSnapshot | undefined, AnswerParams> {
  return { params } as unknown as FirestoreEvent<QueryDocumentSnapshot | undefined, AnswerParams>;
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('makeOnAnswerCreatedHandler', () => {
  it('extracts the path params and drives the service with them', async () => {
    const handle = vi.fn<typeof handleAnswerCreated>(
      async (): Promise<HandleAnswerCreatedOutcome> => ({
        decision: 'revealed',
        coupleId: CID,
        dayKey: DAY_KEY,
        authorUid: UID_B,
        streakApplied: true,
        streakCorrupt: false,
        push: null,
      }),
    );
    const messaging = new FakeMessagingPort();

    await makeOnAnswerCreatedHandler({ handle, messaging, now: () => NOON })(
      answerEvent({ coupleId: CID, dayKey: DAY_KEY, authorUid: UID_B }),
    );

    expect(handle).toHaveBeenCalledTimes(1);
    const [passedDb, passedMessaging, passedEvent] = handle.mock.calls[0];
    expect(passedDb).toBe(db); // getFirestore() singleton
    expect(passedMessaging).toBe(messaging);
    expect(passedEvent).toEqual({ coupleId: CID, dayKey: DAY_KEY, authorUid: UID_B });
  });

  it('drives the real reveal end-to-end from an event (default handle)', async () => {
    await couples.doc(CID).set({
      memberUids: [UID_A, UID_B],
      timezone: 'Europe/Istanbul',
      createdAt: Timestamp.now(),
    });
    const dayRef = couples.doc(CID).collection('days').doc(DAY_KEY);
    await dayRef.set({ questionId: 'solo_tr_001', packId: 'solo_tr', packVersion: 1, assignedAt: Timestamp.now() });
    await dayRef.collection('answers').doc(UID_A).set({ questionId: 'solo_tr_001', text: 'a', answeredAt: Timestamp.now() });
    await dayRef.collection('answers').doc(UID_B).set({ questionId: 'solo_tr_001', text: 'b', answeredAt: Timestamp.now() });

    await makeOnAnswerCreatedHandler({ messaging: new FakeMessagingPort(), now: () => NOON })(
      answerEvent({ coupleId: CID, dayKey: DAY_KEY, authorUid: UID_B }),
    );

    expect((await dayRef.get()).get('revealedAt')).toBeInstanceOf(Timestamp);
    expect((await couples.doc(CID).get()).get('streak')).toEqual({
      count: 1,
      lastMutualDate: DAY_KEY,
      graceTokens: 1,
    });
  });

  it('drops an event with missing path params as a logged error, never driving the service', async () => {
    const handle = vi.fn();
    const errorSpy = vi.spyOn(logger, 'error');

    // authorUid absent — a getFirestore().doc() path built from it would throw.
    await expect(
      makeOnAnswerCreatedHandler({ handle })(answerEvent({ coupleId: CID, dayKey: DAY_KEY })),
    ).resolves.toBeUndefined();

    expect(handle).not.toHaveBeenCalled();
    expect(errorSpy).toHaveBeenCalledWith(
      expect.stringContaining('missing path params'),
      expect.any(Object),
    );
    errorSpy.mockRestore();
  });

  it('drops an event with empty-string params (garbage) without throwing', async () => {
    const handle = vi.fn();
    await expect(
      makeOnAnswerCreatedHandler({ handle })(answerEvent({ coupleId: '', dayKey: '', authorUid: '' })),
    ).resolves.toBeUndefined();
    expect(handle).not.toHaveBeenCalled();
  });

  it('rethrows a genuinely systemic service failure so the run is marked failed', async () => {
    const handle = vi.fn(async () => {
      throw new Error('firestore unavailable');
    });
    await expect(
      makeOnAnswerCreatedHandler({ handle })(answerEvent({ coupleId: CID, dayKey: DAY_KEY, authorUid: UID_B })),
    ).rejects.toThrow('firestore unavailable');
  });
});
