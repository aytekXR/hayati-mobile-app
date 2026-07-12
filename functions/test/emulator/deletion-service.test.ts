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
  // The cursor A SEEDED for B during its detach (the cascade-concurrency fix) is
  // cleaned up by A's seed-cleanup step once the couple sweep confirmed — B (not a
  // deleter here) never adopted it, so no transient deletions/{B} residue survives.
  expect(await exists(db.collection('deletions').doc(B))).toBe(false);

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
  'seed-cleanup',
  'own-sweep',
  'invites-sweep',
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

      // The CASCADE-1 windows: after the detach / couple-sweep kill the live
      // users/{A} is HALF-DETACHED — still present (own-sweep hasn't run) but its
      // coupleId already CLEARED by the detach txn — while the AUTHORITATIVE cursor
      // still holds coupleId=CID. A re-drive that re-derived from the live doc would
      // misread A as unpaired and skip the couple sweep; adopting the cursor is what
      // sweeps the subtree. Asserting the half-detached state makes the re-drive
      // below bite the CASCADE-1 class (subtree still present at 'detach'; and at
      // 'couple-sweep' the seeded deletions/{B} is only cleaned if the re-drive
      // resolves PAIRED off the cursor — assertConverged pins that too).
      if (killStep === 'detach' || killStep === 'couple-sweep') {
        const aSnap = await userRef(A).get();
        expect(aSnap.exists).toBe(true);
        expect(aSnap.get('coupleId')).toBeUndefined();
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
  it("the detach re-pair guard spares B's new couple — B.coupleId != cid is evaluated LIVE", async () => {
    await seedFull();
    // Kill at 'resolve': the cursor is recorded {coupleId:CID, partnerUid:B} but
    // the detach has NOT run, so couple CID and B's coupleId are still untouched.
    // This is the ONLY placement that leaves the couple doc present on the re-drive
    // so the detach txn does not early-return at "already gone" but instead REACHES
    // and evaluates the guard clause `partnerSnap.coupleId === coupleId` (line 143).
    const killAtResolve: DeletionDeps = {
      ...authDeps,
      checkpoint: async (step) => {
        if (step === 'resolve') {
          throw new Error('kill after resolve');
        }
      },
    };
    await expect(deleteAccountCascade(db, A, killAtResolve)).rejects.toThrow();

    // Construct the guard's exact defense state: B re-pairs into a NEW couple while
    // the OLD couple CID STILL EXISTS.
    await coupleRef(CID2).set({ memberUids: [B, C], timezone: 'Europe/Istanbul', createdAt: Timestamp.now() });
    await userRef(B).update({ coupleId: CID2 });

    // Re-drive: cursor names partner B + old couple CID (present) → detach runs the
    // guard; B.coupleId (CID2) !== CID → B is spared (no coupleId clear, no tombstone)
    // BECAUSE of the guard. Weaken `=== coupleId` and B's CID2 is clobbered → red.
    await deleteAccountCascade(db, A, authDeps);

    const bSnap = await userRef(B).get();
    expect(bSnap.get('coupleId')).toBe(CID2); // survived because the guard was false
    expect(bSnap.get('coupleEnded')).toBeUndefined(); // guard skipped the tombstone write
    const newCouple = await coupleRef(CID2).get();
    expect(newCouple.exists).toBe(true);
    expect(newCouple.get('memberUids')).toEqual([B, C]);
    // A itself is fully gone; the OLD couple CID is swept.
    expect(await exists(coupleRef())).toBe(false);
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

  it('same-uid double invocation is resumable — two concurrent A-cascades converge (shared cursor)', async () => {
    await seedFull();
    // Two concurrent invocations of the SAME uid A share deletions/{A}. This proves
    // same-uid resumability under concurrency; it is NOT the both-partners case (the
    // per-uid cursor always protects a uid against ITS OWN interleaving). The genuine
    // A-vs-B partner-detach convergence is carried by the "partner concurrency" suite.
    await Promise.allSettled([
      deleteAccountCascade(db, A, authDeps),
      deleteAccountCascade(db, A, authDeps),
    ]);
    // A final idempotent re-drive settles any interleaving; convergence holds.
    await deleteAccountCascade(db, A, authDeps);
    await assertConverged();
  });
});

describe('deleteAccountCascade — partner concurrency (A and B, distinct uids)', () => {
  /** Kills B right AFTER its detach commits (couple gone, both coupleIds cleared,
   *  deletions/{A} SEEDED by B's detach), the exact cascade-concurrency window. */
  const killBAfterDetach: DeletionDeps = {
    ...authDeps,
    checkpoint: async (step) => {
      if (step === 'detach') {
        throw new Error('kill B after detach');
      }
    },
  };

  it('B seeds A\'s cursor at detach then dies; A ADOPTS it and sweeps the WHOLE couple subtree; B re-drives to full mutual convergence', async () => {
    await seedFull();

    // B deletes first but is killed just after its detach: the detach deleted couple
    // CID, cleared both coupleIds, and SEEDED deletions/{A} (A had not resolved yet).
    await expect(deleteAccountCascade(db, B, killBAfterDetach)).rejects.toThrow();

    // A's cursor was seeded by B's detach: authoritative coupleId, no partnerUid.
    const seeded = await db.collection('deletions').doc(A).get();
    expect(seeded.exists).toBe(true);
    expect(seeded.get('coupleId')).toBe(CID);
    expect(seeded.get('seededByPartner')).toBe(true);
    // A's live users doc is HALF-DETACHED: coupleId already cleared by B's detach.
    expect((await userRef(A).get()).get('coupleId')).toBeUndefined();

    // A now deletes to completion. It ADOPTS the seeded cursor (rather than re-
    // reading the cleared live coupleId and misresolving unpaired) and therefore
    // sweeps the ENTIRE couple subtree ALONE — both authors' answers, both daily
    // lanes, subscriptions — plus A's own subtree + auth.
    await deleteAccountCascade(db, A, authDeps);
    for (const day of [DAY1, DAY2]) {
      expect(await exists(answerRef(CID, day, A))).toBe(false);
      expect(await exists(answerRef(CID, day, B))).toBe(false);
      expect(await exists(dayRef(CID, day))).toBe(false);
    }
    expect(await exists(coupleRef())).toBe(false);
    expect(await exists(db.collection('subscriptions').doc(CID))).toBe(false);
    expect(await exists(db.collection('coachUsage').doc(CID))).toBe(false);
    expect(await exists(db.collection('coachUsage').doc(CID).collection('daily').doc(A))).toBe(false);
    expect(await exists(db.collection('coachUsage').doc(CID).collection('daily').doc(B))).toBe(false);
    expect(await exists(userRef(A))).toBe(false);
    expect(await exists(userRef(A).collection('soloAnswers').doc('20260701'))).toBe(false);
    expect(await exists(db.collection('deletions').doc(A))).toBe(false);
    expect(await authExists(A)).toBe(false);

    // B re-drives its own interrupted cascade → converges (its remaining steps
    // no-op the already-swept subtree and finish B's own erasure).
    await deleteAccountCascade(db, B, authDeps);
    expect(await exists(userRef(B))).toBe(false);
    expect(await exists(userRef(B).collection('soloAnswers').doc('20260701'))).toBe(false);
    expect(await exists(db.collection('invites').doc(INVITE_B_CREATED))).toBe(false);
    expect(await exists(db.collection('deletions').doc(B))).toBe(false);
    expect(await authExists(B)).toBe(false);
  });

  it('abandonment: B detaches then NEVER re-drives; A alone fully sweeps the couple subtree (incl. B-authored answers)', async () => {
    await seedFull();

    // B detaches (seeding A's cursor) and abandons — it never comes back.
    await expect(deleteAccountCascade(db, B, killBAfterDetach)).rejects.toThrow();

    // A runs alone. Because A adopted the seeded cursor, the couple subtree — B's
    // authored answers included — is fully swept by A even though B never returns.
    await deleteAccountCascade(db, A, authDeps);
    for (const day of [DAY1, DAY2]) {
      expect(await exists(answerRef(CID, day, A))).toBe(false);
      expect(await exists(answerRef(CID, day, B))).toBe(false);
    }
    expect(await exists(coupleRef())).toBe(false);
    expect(await exists(db.collection('subscriptions').doc(CID))).toBe(false);
    expect(await exists(userRef(A))).toBe(false);
    expect(await exists(db.collection('deletions').doc(A))).toBe(false);
    expect(await authExists(A)).toBe(false);
  });
});
