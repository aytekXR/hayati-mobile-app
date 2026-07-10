// issueInvite against the firestore emulator: the documented re-issue policy
// (one active invite per creator — return the existing one, never accumulate),
// server-set expiry, collision retry, and the concurrent-issue acceptance
// criterion from resume-prompt Session 007.
import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  INVITE_CODE_ALPHABET,
  INVITE_CODE_LENGTH,
} from '../../src/invites/invite-code';
import {
  CreatorAlreadyPairedError,
  INVITE_TTL_MS,
  InviteCodeSpaceExhaustedError,
  MAX_CODE_ATTEMPTS,
  issueInvite,
} from '../../src/invites/invite-service';
import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();
const invites = db.collection('invites');
const users = db.collection('users');

const CREATOR = 'creator-uid';
/** Valid-charset codes used to seed collisions. */
const TAKEN_CODE = 'TAKEN234';
const FRESH_CODE = 'FRESH234';

function seedInvite(
  code: string,
  data: { creatorUid: string; status: string; expiresAt: Timestamp },
): Promise<FirebaseFirestore.WriteResult> {
  return invites.doc(code).set({ ...data, createdAt: Timestamp.now() });
}

/** Replays `codes`, then keeps returning the last one. */
function riggedGenerator(codes: string[]): () => string {
  let i = 0;
  return () => codes[Math.min(i++, codes.length - 1)];
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('issueInvite', () => {
  it('creates a pending invite with server-set expiry', async () => {
    const before = Date.now();
    const issued = await issueInvite(db, CREATOR);

    expect(issued.code).toMatch(
      new RegExp(`^[${INVITE_CODE_ALPHABET}]{${INVITE_CODE_LENGTH}}$`),
    );
    expect(issued.reused).toBe(false);

    const doc = await invites.doc(issued.code).get();
    expect(doc.exists).toBe(true);
    const data = doc.data()!;
    expect(data.creatorUid).toBe(CREATOR);
    expect(data.status).toBe('pending');
    expect(data.createdAt).toBeInstanceOf(Timestamp);
    // Expiry is computed server-side from the transaction's clock — allow a
    // little skew between this process and the emulator.
    const expiresAt = (data.expiresAt as Timestamp).toMillis();
    expect(expiresAt).toBeGreaterThanOrEqual(before + INVITE_TTL_MS - 15_000);
    expect(expiresAt).toBeLessThanOrEqual(Date.now() + INVITE_TTL_MS + 15_000);
    expect(issued.expiresAtMillis).toBe(expiresAt);
  });

  it('returns the existing active invite instead of accumulating (re-issue policy)', async () => {
    const first = await issueInvite(db, CREATOR);
    const second = await issueInvite(db, CREATOR);

    expect(second.code).toBe(first.code);
    expect(second.reused).toBe(true);
    expect(second.expiresAtMillis).toBe(first.expiresAtMillis);

    const pending = await invites
      .where('creatorUid', '==', CREATOR)
      .where('status', '==', 'pending')
      .get();
    expect(pending.size).toBe(1);
  });

  it('issues a fresh code once the active invite has expired, and marks the stale one expired', async () => {
    await seedInvite(TAKEN_CODE, {
      creatorUid: CREATOR,
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() - 1),
    });

    const issued = await issueInvite(db, CREATOR);

    expect(issued.code).not.toBe(TAKEN_CODE);
    expect(issued.reused).toBe(false);
    const stale = await invites.doc(TAKEN_CODE).get();
    expect(stale.data()!.status).toBe('expired');
  });

  it('retries on code collision inside the transaction', async () => {
    await seedInvite(TAKEN_CODE, {
      creatorUid: 'someone-else',
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + INVITE_TTL_MS),
    });

    const issued = await issueInvite(
      db,
      CREATOR,
      riggedGenerator([TAKEN_CODE, FRESH_CODE]),
    );

    expect(issued.code).toBe(FRESH_CODE);
    // The colliding invite is untouched.
    const taken = await invites.doc(TAKEN_CODE).get();
    expect(taken.data()!.creatorUid).toBe('someone-else');
  });

  it('gives up loudly when the code space refuses to yield', async () => {
    await seedInvite(TAKEN_CODE, {
      creatorUid: 'someone-else',
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + INVITE_TTL_MS),
    });

    await expect(
      issueInvite(db, CREATOR, riggedGenerator([TAKEN_CODE])),
    ).rejects.toBeInstanceOf(InviteCodeSpaceExhaustedError);
    // Sanity: the generator really was given MAX_CODE_ATTEMPTS chances.
    expect(MAX_CODE_ATTEMPTS).toBeGreaterThanOrEqual(3);
  });

  it('concurrent issue attempts converge on a single code (acceptance criterion)', async () => {
    const [a, b] = await Promise.all([
      issueInvite(db, CREATOR),
      issueInvite(db, CREATOR),
    ]);

    expect(a.code).toBe(b.code);
    expect([a.reused, b.reused].filter((reused) => reused)).toHaveLength(1);

    const pending = await invites
      .where('creatorUid', '==', CREATOR)
      .where('status', '==', 'pending')
      .get();
    expect(pending.size).toBe(1);
  });

  // M2.3 already-paired guard: coupleId on the creator's users doc blocks any
  // new (or re-used) invite. A profile without coupleId, or no profile at all,
  // keeps the M2.1 behavior (issue proceeds).
  it('refuses to issue for an already-paired creator', async () => {
    await users.doc(CREATOR).set({ coupleId: 'existing-couple' });
    await expect(issueInvite(db, CREATOR)).rejects.toBeInstanceOf(
      CreatorAlreadyPairedError,
    );
    const any = await invites.where('creatorUid', '==', CREATOR).get();
    expect(any.empty).toBe(true);
  });

  it('still issues when the creator has a profile without a coupleId', async () => {
    await users.doc(CREATOR).set({
      status: 'married',
      contentLanguage: 'tr',
      register: 'respectful',
      createdAt: Timestamp.now(),
    });
    const issued = await issueInvite(db, CREATOR);
    expect(issued.reused).toBe(false);
    expect((await invites.doc(issued.code).get()).data()!.creatorUid).toBe(
      CREATOR,
    );
  });
});
