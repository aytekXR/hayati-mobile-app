// Thin e2e for the answerReveal WIRE itself (ADR-012 D1): does the functions
// emulator actually deliver the onDocumentCreated trigger to the BUILT lib/
// Function? The transactional semantics are proven in-process by
// reveal-service.test.ts; this only asserts the trigger fires end-to-end when a
// second answer doc is created, by polling the day doc for revealedAt.
//
// Trigger delivery is a known emulator soft spot (resume-prompt stopping
// condition). If this flakes in CI, the in-process suite carries the acceptance
// and the wire is deploy-verified at the first Blaze deploy — same posture as
// the rollover schedule trigger. Skip THIS test (with a comment) if so.
//
// No users docs are seeded on purpose: the production handler runs the real
// FcmMessagingPort, so empty fcmTokens make the push a no-op skip and no
// getMessaging() call (which has no emulator) is ever attempted — the reveal's
// revealedAt still commits inside the transaction regardless.
import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();

// Distinct couple id so a lagging trigger from another suite cannot touch it.
const CID = 'couple-e2e-trigger';
const DAY_KEY = '20260710';

async function pollRevealedAt(timeoutMs: number): Promise<unknown> {
  const dayRef = db.collection('couples').doc(CID).collection('days').doc(DAY_KEY);
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const revealedAt = (await dayRef.get()).get('revealedAt');
    if (revealedAt != null) {
      return revealedAt;
    }
    await new Promise((res) => setTimeout(res, 250));
  }
  return undefined;
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('answerReveal trigger wire (emulator delivery)', () => {
  it('delivering the second answer create fires the built Function → revealedAt stamped', async () => {
    const couple = db.collection('couples').doc(CID);
    await couple.set({
      memberUids: ['uid-a', 'uid-b'],
      timezone: 'Europe/Istanbul',
      createdAt: Timestamp.now(),
    });
    const dayRef = couple.collection('days').doc(DAY_KEY);
    await dayRef.set({
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
    });

    const answers = dayRef.collection('answers');
    await answers.doc('uid-a').set({ questionId: 'solo_tr_001', text: 'first', answeredAt: Timestamp.now() });
    // The CREATE of the second answer is what the trigger latches on.
    await answers.doc('uid-b').set({ questionId: 'solo_tr_001', text: 'second', answeredAt: Timestamp.now() });

    const revealedAt = await pollRevealedAt(20_000);
    expect(revealedAt).toBeInstanceOf(Timestamp);

    // The same delivery folded the mutual day into the streak (first mutual day).
    expect((await couple.get()).get('streak')).toEqual({
      count: 1,
      lastMutualDate: DAY_KEY,
      graceTokens: 1,
    });
  });
});
