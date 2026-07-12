// The Firestore + Auth half of the M6.2 hard cascade delete (ADR-019 Decision 2).
// `db` is injected by the shell (the coach-service mold). The cascade is ONE
// idempotent, resumable pipeline: a cursor doc (deletions/{uid}) is written before
// any destructive step and is AUTHORITATIVE whenever present (the CASCADE-1 fix —
// re-drives never re-derive membership from a half-detached users doc), every
// sweep confirms-or-throws BEFORE the auth delete (the SWEEP-2 fix — a swallowed
// delete + auth-deleted-last would be permanent success-with-residue), and the
// Auth deletion is last and idempotent via the plural deleteUsers([uid]) (the
// AUTH-3 fix — a lost step-7 ack must never strand a fully-erased account in
// "deletion failed"). An injectable checkpoint(step) seam drives the resumability
// tests; a re-drive is a re-run from the top with every completed step a no-op.
import { getAuth } from 'firebase-admin/auth';
import type { DeleteUsersResult } from 'firebase-admin/auth';
import {
  DocumentReference,
  FieldValue,
  Firestore,
} from 'firebase-admin/firestore';

import { CascadeStep } from './data-rights-core';

/** Success is the only non-throwing terminal — any residue or infra fault throws. */
export interface DeletionResult {
  status: 'deleted';
}

export interface DeletionDeps {
  /**
   * Test seam (the reveal-service deps.beforeWrite prior art): awaited after EACH
   * step, including the explicit one around the non-transactional auth delete. A
   * throw here simulates a kill-mid-cascade; the resumability suite re-drives.
   */
  checkpoint?: (step: CascadeStep) => Promise<void>;
  /**
   * The single-doc delete used by the confirm-or-throw sweeps (steps 3/4/5). Each
   * op promise is awaited and a rejection aborts the callable before the auth
   * delete. Injectable so a fault-injection test can force one delete to fail.
   */
  deleteRef?: (ref: DocumentReference) => Promise<void>;
  /**
   * Auth deletion (step 7): the documented-idempotent PLURAL form. Injectable so
   * the in-process suite can point it at the test project's auth emulator.
   */
  deleteAuthUsers?: (uids: string[]) => Promise<DeleteUsersResult>;
}

const AUTH_USER_NOT_FOUND = 'auth/user-not-found';

/** The authoritative cursor (or the initial live resolution used to write it). */
interface Resolution {
  coupleId: string | null;
  partnerUid: string | null;
  /** True when a prior run died after step 6: only the auth delete remains. */
  authOnly: boolean;
}

function partnerOf(members: unknown, uid: string): string | null {
  if (!Array.isArray(members)) {
    return null;
  }
  const partner = members.find((u) => typeof u === 'string' && u !== uid);
  return typeof partner === 'string' ? partner : null;
}

/**
 * Step 1 — resolve + record. Reads the cursor FIRST; whenever it exists its
 * recorded coupleId/partnerUid drive the couple steps (never re-derived from the
 * live users doc). Only on the very first run — cursor absent — is users/{A}.coupleId
 * read, the partner resolved off the (still-present) couple, and the cursor
 * merge-written before any destructive step. Both cursor and users absent means a
 * prior run finished through step 6: only the auth delete remains.
 */
async function resolveAndRecord(db: Firestore, uid: string): Promise<Resolution> {
  const cursorRef = db.collection('deletions').doc(uid);
  const cursorSnap = await cursorRef.get();
  if (cursorSnap.exists) {
    const rawCid = cursorSnap.get('coupleId');
    const rawPartner = cursorSnap.get('partnerUid');
    return {
      coupleId: typeof rawCid === 'string' && rawCid.length > 0 ? rawCid : null,
      partnerUid: typeof rawPartner === 'string' && rawPartner.length > 0 ? rawPartner : null,
      authOnly: false,
    };
  }

  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) {
    return { coupleId: null, partnerUid: null, authOnly: true };
  }

  const rawCid = userSnap.get('coupleId');
  const coupleId = typeof rawCid === 'string' && rawCid.length > 0 ? rawCid : null;
  let partnerUid: string | null = null;
  if (coupleId !== null) {
    const coupleSnap = await db.collection('couples').doc(coupleId).get();
    if (coupleSnap.exists) {
      partnerUid = partnerOf(coupleSnap.get('memberUids'), uid);
    }
  }

  const cursor: Record<string, unknown> = {
    coupleId,
    startedAt: FieldValue.serverTimestamp(),
  };
  if (partnerUid !== null) {
    cursor.partnerUid = partnerUid;
  }
  await cursorRef.set(cursor, { merge: true });
  return { coupleId, partnerUid, authOnly: false };
}

/**
 * Step 2 — the detach transaction (skipped when unpaired or the couple is already
 * gone). Deletes the couple doc FIRST (fail-closes both members' couple-scoped
 * surface instantly), clears B's coupleId and stamps coupleEnded.at ATOMICALLY —
 * but only if B still points at THIS couple (re-pair guard), so a stale re-drive
 * never dents B's new relationship — and clears A's coupleId. All reads precede
 * all writes (the standing transaction shape).
 */
async function detach(
  db: Firestore,
  uid: string,
  coupleId: string,
  partnerUid: string | null,
): Promise<void> {
  const coupleRef = db.collection('couples').doc(coupleId);
  const selfRef = db.collection('users').doc(uid);
  const partnerRef = partnerUid !== null ? db.collection('users').doc(partnerUid) : null;

  await db.runTransaction(async (tx) => {
    const coupleSnap = await tx.get(coupleRef);
    if (!coupleSnap.exists) {
      return; // already gone — the re-drive no-op
    }
    const partnerSnap = partnerRef !== null ? await tx.get(partnerRef) : null;
    const selfSnap = await tx.get(selfRef);

    tx.delete(coupleRef);
    if (
      partnerRef !== null &&
      partnerSnap !== null &&
      partnerSnap.exists &&
      partnerSnap.get('coupleId') === coupleId
    ) {
      tx.update(partnerRef, {
        coupleId: FieldValue.delete(),
        coupleEnded: { at: FieldValue.serverTimestamp() },
      });
    }
    if (selfSnap.exists) {
      tx.update(selfRef, { coupleId: FieldValue.delete() });
    }
  });
}

/**
 * Step 3 — couple-subtree sweep. Orphaned subcollections stay listable after the
 * parent doc's deletion, so listDocuments() enumerates them: every
 * days/{d}/answers/*, every days/{d}, coachUsage/{cid}/daily/*, coachUsage/{cid},
 * subscriptions/{cid}. Every delete is awaited (confirm-or-throw); a rejection
 * aborts the callable before the auth delete.
 */
async function sweepCoupleSubtree(
  db: Firestore,
  coupleId: string,
  deleteRef: (ref: DocumentReference) => Promise<void>,
): Promise<void> {
  const coupleRef = db.collection('couples').doc(coupleId);
  const dayRefs = await coupleRef.collection('days').listDocuments();
  for (const dayRef of dayRefs) {
    const answerRefs = await dayRef.collection('answers').listDocuments();
    await Promise.all(answerRefs.map(deleteRef));
    await deleteRef(dayRef);
  }

  const coachUsageRef = db.collection('coachUsage').doc(coupleId);
  const dailyRefs = await coachUsageRef.collection('daily').listDocuments();
  await Promise.all(dailyRefs.map(deleteRef));
  await deleteRef(coachUsageRef);

  await deleteRef(db.collection('subscriptions').doc(coupleId));
}

/**
 * Step 4 — invites sweep: every invite naming A (creatorUid == A, then
 * joinerUid == A), de-duplicated by id. Both are single-field equality queries
 * (auto-indexed). Confirm-or-throw like every sweep.
 */
async function sweepInvites(
  db: Firestore,
  uid: string,
  deleteRef: (ref: DocumentReference) => Promise<void>,
): Promise<void> {
  const invites = db.collection('invites');
  const [created, joined] = await Promise.all([
    invites.where('creatorUid', '==', uid).get(),
    invites.where('joinerUid', '==', uid).get(),
  ]);
  const refs = new Map<string, DocumentReference>();
  for (const snap of [...created.docs, ...joined.docs]) {
    refs.set(snap.id, snap.ref);
  }
  await Promise.all([...refs.values()].map(deleteRef));
}

/**
 * Step 5 — own-subtree sweep: every users/{A}/soloAnswers/*, then users/{A}
 * itself. The solo-answer residue would be exactly as permanent as any other, so
 * it confirms-or-throws too.
 */
async function sweepOwnSubtree(
  db: Firestore,
  uid: string,
  deleteRef: (ref: DocumentReference) => Promise<void>,
): Promise<void> {
  const selfRef = db.collection('users').doc(uid);
  const soloRefs = await selfRef.collection('soloAnswers').listDocuments();
  await Promise.all(soloRefs.map(deleteRef));
  await deleteRef(selfRef);
}

/**
 * Step 7 — delete the Auth user idempotently. The plural deleteUsers is documented
 * to treat an already-absent uid as a success (it never appears as a failure
 * entry); we defensively inspect the result anyway — a user-not-found failure
 * entry is success, any OTHER failure entry throws.
 */
function assertAuthDeleted(result: DeleteUsersResult): void {
  for (const failure of result.errors) {
    const code = (failure.error as { code?: unknown }).code;
    if (code !== AUTH_USER_NOT_FOUND) {
      throw new Error(
        `auth deletion failed: ${typeof code === 'string' ? code : 'unknown'}`,
      );
    }
  }
}

/**
 * Drives the whole cascade for `uid` (ADR-019 Decision 2). Returns
 * `{ status: 'deleted' }` only after every destructive Firestore step confirmed
 * zero residue and the Auth user is gone. Any sweep failure or infra fault throws
 * (A stays authenticated, auth delete not reached) so the caller can re-drive.
 */
export async function deleteAccountCascade(
  db: Firestore,
  uid: string,
  deps: DeletionDeps = {},
): Promise<DeletionResult> {
  const checkpoint = deps.checkpoint ?? (async () => undefined);
  const deleteRef =
    deps.deleteRef ??
    (async (ref: DocumentReference) => {
      await ref.delete();
    });
  const deleteAuthUsers =
    deps.deleteAuthUsers ?? ((uids: string[]) => getAuth().deleteUsers(uids));

  // Step 1 — resolve + record.
  const resolution = await resolveAndRecord(db, uid);
  await checkpoint('resolve');

  if (!resolution.authOnly) {
    const { coupleId, partnerUid } = resolution;

    // Step 2 — detach transaction.
    if (coupleId !== null) {
      await detach(db, uid, coupleId, partnerUid);
    }
    await checkpoint('detach');

    // Step 3 — couple-subtree sweep.
    if (coupleId !== null) {
      await sweepCoupleSubtree(db, coupleId, deleteRef);
    }
    await checkpoint('couple-sweep');

    // Step 4 — invites sweep.
    await sweepInvites(db, uid, deleteRef);
    await checkpoint('invites-sweep');

    // Step 5 — own-subtree sweep.
    await sweepOwnSubtree(db, uid, deleteRef);
    await checkpoint('own-sweep');

    // Step 6 — remove the cursor (only reachable after 2–5 confirmed).
    await db.collection('deletions').doc(uid).delete();
    await checkpoint('remove-cursor');
  }

  // Step 7 — delete the Auth user, idempotently and last.
  assertAuthDeleted(await deleteAuthUsers([uid]));
  await checkpoint('auth-delete');

  return { status: 'deleted' };
}
