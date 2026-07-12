// The M6.2 hard cascade delete against the firestore + auth emulators (ADR-019
// Decision 2, Test commitments). THE acceptance proof at the service level: the
// full doc-by-doc erasure, idempotency, per-step resumability through the
// AUTHORITATIVE cursor (the CASCADE-1 windows k=detach/k=couple-sweep get named
// assertions), the confirm-or-throw sweep contract (the SWEEP-2 fix), the re-pair
// guard, unpaired delete, and concurrent double-delete convergence.
//
// Seeded on the NO_TRIGGER project (admin.ts): the functions emulator does not
// watch it, so seeding couple answer docs never fires the live answerReveal
// trigger to race the in-process cascade. Auth lives on the same project's auth
// emulator; the auth-delete seam is injected to target it.
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import type { DeleteUsersResult } from 'firebase-admin/auth';
import { DocumentReference, Firestore, Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { CascadeStep } from '../../src/data-rights/data-rights-core';
import {
  DeletionDeps,
  deleteAccountCascade,
} from '../../src/data-rights/deletion-service';
import { EMULATOR_PROJECT_ID, clearNoTriggerFirestore, noTriggerFirestore } from '../support/admin';

// Firestore seeding lives on the trigger-isolated project (seeds answer docs);
// the auth-user lifecycle uses the default project's auth emulator (the shape the
// invite-preview suite already proves works), decoupled from Firestore triggers.
const db: Firestore = noTriggerFirestore();
if (getApps().every((a) => a.name !== '[DEFAULT]')) {
  initializeApp({ projectId: EMULATOR_PROJECT_ID });
}
const auth = getAuth();

const A = 'del-a';
const B = 'del-b';
const C = 'del-c';
const CID = 'del-couple';
const CID2 = 'del-couple-2';
const DAY1 = '20260709';
const DAY2 = '20260710';
const INVITE_A_CREATED = 'AAAA2222';
const INVITE_A_JOINED = 'BBBB3333';
const INVITE_B_CREATED = 'CCCC4444';

const authDeps: DeletionDeps = {
  deleteAuthUsers: (uids: string[]): Promise<DeleteUsersResult> => auth.deleteUsers(uids),
};

function userRef(uid: string): DocumentReference {
  return db.collection('users').doc(uid);
}
function coupleRef(cid = CID): DocumentReference {
  return db.collection('couples').doc(cid);
}
function dayRef(cid: string, day: string): DocumentReference {
  return coupleRef(cid).collection('days').doc(day);
}
function answerRef(cid: string, day: string, uid: string): DocumentReference {
  return dayRef(cid, day).collection('answers').doc(uid);
}

async function putAuthUser(uid: string): Promise<void> {
  await auth.deleteUser(uid).catch(() => undefined);
  await auth.createUser({ uid });
}
async function authExists(uid: string): Promise<boolean> {
  return auth.getUser(uid).then(
    () => true,
    () => false,
  );
}
async function exists(ref: DocumentReference): Promise<boolean> {
  return (await ref.get()).exists;
}

/** The full two-member fixture (both authors' answers, subscriptions, coach lanes,
 *  invites both directions, solo answers both users) + both auth records. */
async function seedFull(): Promise<void> {
  await coupleRef().set({
    memberUids: [A, B],
    timezone: 'Europe/Istanbul',
    createdAt: Timestamp.now(),
    streak: { count: 3, lastMutualDate: '20260709', graceTokens: 1 },
  });
  for (const day of [DAY1, DAY2]) {
    await dayRef(CID, day).set({
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
      revealedAt: Timestamp.now(),
    });
    await answerRef(CID, day, A).set({ questionId: 'solo_tr_001', text: `A ${day}`, answeredAt: Timestamp.now() });
    await answerRef(CID, day, B).set({ questionId: 'solo_tr_001', text: `B ${day}`, answeredAt: Timestamp.now() });
  }
  await db.collection('subscriptions').doc(CID).set({
    entitled: true,
    expiresAtMs: Date.now() + 10_000_000_000,
    lanes: { [A]: { entitled: true }, [B]: { entitled: true } },
    updatedAt: Timestamp.now(),
  });
  await db.collection('coachUsage').doc(CID).set({ monthly: { monthKey: '202607', count: 9 }, updatedAt: Timestamp.now() });
  await db.collection('coachUsage').doc(CID).collection('daily').doc(A).set({ dayKey: DAY2, count: 2, updatedAt: Timestamp.now() });
  await db.collection('coachUsage').doc(CID).collection('daily').doc(B).set({ dayKey: DAY2, count: 5, updatedAt: Timestamp.now() });
  await db.collection('invites').doc(INVITE_A_CREATED).set({ creatorUid: A, status: 'pending', expiresAt: Timestamp.fromMillis(Date.now() + 60_000), createdAt: Timestamp.now() });
  await db.collection('invites').doc(INVITE_A_JOINED).set({ creatorUid: 'someone', joinerUid: A, status: 'joined', coupleId: 'old', joinedAt: Timestamp.now(), createdAt: Timestamp.now() });
  await db.collection('invites').doc(INVITE_B_CREATED).set({ creatorUid: B, status: 'pending', expiresAt: Timestamp.fromMillis(Date.now() + 60_000), createdAt: Timestamp.now() });
  await userRef(A).set({ status: 'married', contentLanguage: 'tr', register: 'respectful', coupleId: CID, createdAt: Timestamp.now() });
  await userRef(B).set({ status: 'married', contentLanguage: 'ar', register: 'respectful', coupleId: CID, createdAt: Timestamp.now() });
  await userRef(A).collection('soloAnswers').doc('20260701').set({ questionId: 'solo_tr_1', text: 'A solo', answeredAt: Timestamp.now() });
  await userRef(B).collection('soloAnswers').doc('20260701').set({ questionId: 'solo_tr_1', text: 'B solo', answeredAt: Timestamp.now() });
  await putAuthUser(A);
  await putAuthUser(B);
}

/** Everything A-scoped / couple-scoped is gone; B's own space survives. */
async function assertConverged(): Promise<void> {
  expect(await exists(coupleRef())).toBe(false);
  for (const day of [DAY1, DAY2]) {
    expect(await exists(dayRef(CID, day))).toBe(false);
    expect(await exists(answerRef(CID, day, A))).toBe(false);
    expect(await exists(answerRef(CID, day, B))).toBe(false);
  }
  expect(await exists(db.collection('subscriptions').doc(CID))).toBe(false);
  expect(await exists(db.collection('coachUsage').doc(CID))).toBe(false);
  expect(await exists(db.collection('coachUsage').doc(CID).collection('daily').doc(A))).toBe(false);
  expect(await exists(db.collection('coachUsage').doc(CID).collection('daily').doc(B))).toBe(false);
  expect(await exists(db.collection('invites').doc(INVITE_A_CREATED))).toBe(false);
  expect(await exists(db.collection('invites').doc(INVITE_A_JOINED))).toBe(false);
  expect(await exists(userRef(A))).toBe(false);
  expect(await exists(userRef(A).collection('soloAnswers').doc('20260701'))).toBe(false);
  expect(await exists(db.collection('deletions').doc(A))).toBe(false);
  expect(await authExists(A)).toBe(false);

  // B's own space is intact; the notification tombstone is present, coupleId gone.
  const bSnap = await userRef(B).get();
  expect(bSnap.exists).toBe(true);
  expect(bSnap.get('coupleId')).toBeUndefined();
  const coupleEnded = bSnap.get('coupleEnded') as { at?: unknown } | undefined;
  expect(coupleEnded).toBeDefined();
  expect(coupleEnded?.at).toBeDefined();
  expect(await exists(userRef(B).collection('soloAnswers').doc('20260701'))).toBe(true);
  expect(await exists(db.collection('invites').doc(INVITE_B_CREATED))).toBe(true);
  expect(await authExists(B)).toBe(true);
}

beforeEach(async () => {
  await clearNoTriggerFirestore();
  for (const uid of [A, B, C]) {
    await auth.deleteUser(uid).catch(() => undefined);
  }
});

describe('deleteAccountCascade — full fixture', () => {
  it('erases every A-scoped and couple-scoped doc; B keeps their own space + the tombstone', async () => {
    await seedFull();
    const result = await deleteAccountCascade(db, A, authDeps);
    expect(result).toEqual({ status: 'deleted' });
    await assertConverged();
  });

  it('is idempotent — a second run does not throw and the postconditions hold', async () => {
    await seedFull();
    await deleteAccountCascade(db, A, authDeps);
    // Second run: cursor + users/A gone → auth-only path, deleteUsers is a no-op success.
    const again = await deleteAccountCascade(db, A, authDeps);
    expect(again).toEqual({ status: 'deleted' });
    await assertConverged();
  });
});

const STEPS: CascadeStep[] = [
  'resolve',
  'detach',
  'couple-sweep',
  'invites-sweep',
  'own-sweep',
  'remove-cursor',
  'auth-delete',
];

describe('deleteAccountCascade — resumability (kill after each step, re-drive converges)', () => {
  for (const killStep of STEPS) {
    it(`re-drives to full convergence after a kill at step "${killStep}"`, async () => {
      await seedFull();
      const killing: DeletionDeps = {
        ...authDeps,
        checkpoint: async (step) => {
          if (step === killStep) {
            throw new Error(`kill after ${step}`);
          }
        },
      };
      await expect(deleteAccountCascade(db, A, killing)).rejects.toThrow();

      // The CASCADE-1 windows: after the detach / couple-sweep kill the cursor is
      // AUTHORITATIVE (holds coupleId), so the re-drive sweeps the couple subtree
      // via the cursor rather than re-deriving unpaired from a half-detached A.
      if (killStep === 'detach' || killStep === 'couple-sweep') {
        const cursor = await db.collection('deletions').doc(A).get();
        expect(cursor.exists).toBe(true);
        expect(cursor.get('coupleId')).toBe(CID);
      }
      // Auth is deleted last: any kill before step 7 leaves A authenticated.
      if (killStep !== 'auth-delete') {
        expect(await authExists(A)).toBe(true);
      }

      await deleteAccountCascade(db, A, authDeps);
      await assertConverged();
    });
  }
});

describe('deleteAccountCascade — sweep confirm-or-throw (SWEEP-2)', () => {
  const sweepTargets: { step: string; targetPath: () => string }[] = [
    { step: 'couple-sweep', targetPath: () => answerRef(CID, DAY2, A).path },
    { step: 'invites-sweep', targetPath: () => db.collection('invites').doc(INVITE_A_CREATED).path },
    { step: 'own-sweep', targetPath: () => userRef(A).collection('soloAnswers').doc('20260701').path },
  ];

  for (const { step, targetPath } of sweepTargets) {
    it(`aborts before the auth delete when a delete in "${step}" fails, then re-drives clean`, async () => {
      await seedFull();
      const target = targetPath();
      const failing: DeletionDeps = {
        ...authDeps,
        deleteRef: async (ref: DocumentReference) => {
          if (ref.path === target) {
            throw new Error('delete failed');
          }
          await ref.delete();
        },
      };
      await expect(deleteAccountCascade(db, A, failing)).rejects.toThrow('delete failed');
      // The auth user survives — the callable never reached step 7.
      expect(await authExists(A)).toBe(true);

      await deleteAccountCascade(db, A, authDeps);
      await assertConverged();
    });
  }
});

describe('deleteAccountCascade — re-pair guard, unpaired, concurrent', () => {
  it('a stale re-drive after B re-paired never dents B\'s new couple', async () => {
    await seedFull();
    // Kill right after the detach (couple gone, B detached + tombstoned, cursor present).
    const killAfterDetach: DeletionDeps = {
      ...authDeps,
      checkpoint: async (step) => {
        if (step === 'detach') {
          throw new Error('kill after detach');
        }
      },
    };
    await expect(deleteAccountCascade(db, A, killAfterDetach)).rejects.toThrow();

    // B re-pairs into a brand-new couple.
    await coupleRef(CID2).set({ memberUids: [B, C], timezone: 'Europe/Istanbul', createdAt: Timestamp.now() });
    await userRef(B).update({ coupleId: CID2 });

    // Re-drive A's deletion: the cursor names the OLD couple (gone) → detach skips.
    await deleteAccountCascade(db, A, authDeps);

    const bSnap = await userRef(B).get();
    expect(bSnap.get('coupleId')).toBe(CID2);
    const newCouple = await coupleRef(CID2).get();
    expect(newCouple.exists).toBe(true);
    expect(newCouple.get('memberUids')).toEqual([B, C]);
    expect(await exists(userRef(A))).toBe(false);
    expect(await authExists(A)).toBe(false);
  });

  it('an unpaired A converges (profile, solo answers, invites, auth)', async () => {
    await userRef(A).set({ status: 'dating', contentLanguage: 'tr', register: 'playful', createdAt: Timestamp.now() });
    await userRef(A).collection('soloAnswers').doc('20260701').set({ questionId: 'q', text: 'solo', answeredAt: Timestamp.now() });
    await db.collection('invites').doc(INVITE_A_CREATED).set({ creatorUid: A, status: 'pending', expiresAt: Timestamp.fromMillis(Date.now() + 60_000), createdAt: Timestamp.now() });
    await putAuthUser(A);

    const result = await deleteAccountCascade(db, A, authDeps);
    expect(result).toEqual({ status: 'deleted' });
    expect(await exists(userRef(A))).toBe(false);
    expect(await exists(userRef(A).collection('soloAnswers').doc('20260701'))).toBe(false);
    expect(await exists(db.collection('invites').doc(INVITE_A_CREATED))).toBe(false);
    expect(await exists(db.collection('deletions').doc(A))).toBe(false);
    expect(await authExists(A)).toBe(false);
  });

  it('concurrent double-delete converges by idempotency', async () => {
    await seedFull();
    // Both partners (well, both invocations of A) fire at once.
    await Promise.allSettled([
      deleteAccountCascade(db, A, authDeps),
      deleteAccountCascade(db, A, authDeps),
    ]);
    // A final idempotent re-drive settles any interleaving; convergence holds.
    await deleteAccountCascade(db, A, authDeps);
    await assertConverged();
  });
});
