// joinInvite against the firestore emulator (admin SDK, rules-bypassing like
// the deployed Function): the ONE-transaction couple creation, the documented
// check order, the timezone fallback, and the acceptance-criterion CONCURRENT
// RACE — two joiners on one code converge on exactly one couple, the loser gets
// the consumed rejection from re-read state. Requires the firestore emulator:
//   firebase emulators:exec --only auth,firestore,functions \
//     --project demo-hayati 'cd functions && npm run test:ci'
import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  CreatorAlreadyPairedError,
  issueInvite,
} from '../../src/invites/invite-service';
import {
  AlreadyPairedError,
  ConsumedInviteError,
  DEFAULT_COUPLE_TIMEZONE,
  ExpiredInviteError,
  ProfileMissingError,
  SelfJoinError,
  UnknownInviteError,
  joinInvite,
} from '../../src/invites/join-service';
import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();
const invites = db.collection('invites');
const users = db.collection('users');
const couples = db.collection('couples');

const CREATOR = 'creator-uid';
const JOINER = 'joiner-uid';
const JOINER_A = 'joiner-a-uid';
const JOINER_B = 'joiner-b-uid';

// Valid-charset codes (alphabet A/B/C + digits 2-6) — one per scenario so a
// leaked write from one test can never satisfy another.
const CODE = 'AAAA2222';

/** Seeds a users/{uid} profile; pass a coupleId to seed an already-paired one. */
function seedProfile(uid: string, coupleId?: string): Promise<unknown> {
  return users.doc(uid).set({
    status: 'married',
    contentLanguage: 'tr',
    register: 'respectful',
    createdAt: Timestamp.now(),
    ...(coupleId === undefined ? {} : { coupleId }),
  });
}

/** Seeds a pending invite (creatorUid CREATOR, unexpired) with field overrides. */
function seedInvite(
  code: string,
  overrides: Record<string, unknown> = {},
): Promise<unknown> {
  return invites.doc(code).set({
    creatorUid: CREATOR,
    status: 'pending',
    expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    createdAt: Timestamp.now(),
    ...overrides,
  });
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('joinInvite — happy path', () => {
  it('creates the couple, pairs both partners, and marks the invite joined', async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER);
    await seedInvite(CODE);

    const before = Date.now();
    const result = await joinInvite(db, JOINER, CODE);

    // Couple doc shape (architecture.md §3): creator-first memberUids, the
    // default timezone (none supplied), a server-stamped createdAt.
    const coupleSnap = await couples.doc(result.coupleId).get();
    expect(coupleSnap.exists).toBe(true);
    const couple = coupleSnap.data()!;
    expect(couple.memberUids).toEqual([CREATOR, JOINER]);
    expect(couple.timezone).toBe(DEFAULT_COUPLE_TIMEZONE);
    expect(couple.createdAt).toBeInstanceOf(Timestamp);
    expect((couple.createdAt as Timestamp).toMillis()).toBeGreaterThanOrEqual(
      before - 15_000,
    );

    // Both users now point at the couple.
    expect((await users.doc(CREATOR).get()).get('coupleId')).toBe(
      result.coupleId,
    );
    expect((await users.doc(JOINER).get()).get('coupleId')).toBe(
      result.coupleId,
    );

    // Invite terminal fields.
    const invite = (await invites.doc(CODE).get()).data()!;
    expect(invite.status).toBe('joined');
    expect(invite.coupleId).toBe(result.coupleId);
    expect(invite.joinerUid).toBe(JOINER);
    expect(invite.joinedAt).toBeInstanceOf(Timestamp);
  });
});

describe('joinInvite — timezone', () => {
  beforeEach(async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER);
    await seedInvite(CODE);
  });

  it('keeps a valid device-supplied timezone', async () => {
    const { coupleId } = await joinInvite(db, JOINER, CODE, 'Asia/Riyadh');
    expect((await couples.doc(coupleId).get()).get('timezone')).toBe(
      'Asia/Riyadh',
    );
  });

  it('falls back to the default for an invalid timezone', async () => {
    const { coupleId } = await joinInvite(db, JOINER, CODE, 'Mars/Base');
    expect((await couples.doc(coupleId).get()).get('timezone')).toBe(
      DEFAULT_COUPLE_TIMEZONE,
    );
  });

  it('falls back to the default when the timezone is absent', async () => {
    const { coupleId } = await joinInvite(db, JOINER, CODE);
    expect((await couples.doc(coupleId).get()).get('timezone')).toBe(
      DEFAULT_COUPLE_TIMEZONE,
    );
  });
});

describe('joinInvite — typed rejections', () => {
  it("rejects an absent invite as 'unknown'", async () => {
    await seedProfile(JOINER);
    await expect(joinInvite(db, JOINER, 'ZZZZ9999')).rejects.toBeInstanceOf(
      UnknownInviteError,
    );
  });

  it("rejects a malformed code as 'unknown' without touching Firestore", async () => {
    await expect(joinInvite(db, JOINER, 'not-a-code')).rejects.toBeInstanceOf(
      UnknownInviteError,
    );
  });

  it("rejects an invite already marked 'expired'", async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER);
    await seedInvite(CODE, { status: 'expired' });
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      ExpiredInviteError,
    );
  });

  it("rejects a pending invite past its expiresAt", async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER);
    await seedInvite(CODE, { expiresAt: Timestamp.fromMillis(Date.now() - 1) });
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      ExpiredInviteError,
    );
  });

  it("rejects a malformed invite doc with no expiresAt as expired", async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER);
    // A doc missing expiresAt entirely (not just past) is defensively expired.
    await invites.doc(CODE).set({
      creatorUid: CREATOR,
      status: 'pending',
      createdAt: Timestamp.now(),
    });
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      ExpiredInviteError,
    );
  });

  it("rejects a 'joined' invite as consumed (reused code)", async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER);
    // A joined invite even with a future expiresAt is consumed, not expired.
    await seedInvite(CODE, { status: 'joined' });
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      ConsumedInviteError,
    );
  });

  it('rejects a self-join before it even reads a profile', async () => {
    // No profiles seeded: self-join is checked before profile-missing, so the
    // creator joining their own code fails self-join regardless.
    await seedInvite(CODE);
    await expect(joinInvite(db, CREATOR, CODE)).rejects.toBeInstanceOf(
      SelfJoinError,
    );
  });

  it("rejects when the joiner has no profile", async () => {
    await seedProfile(CREATOR);
    await seedInvite(CODE);
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      ProfileMissingError,
    );
  });

  it("rejects when the creator has no profile", async () => {
    await seedProfile(JOINER);
    await seedInvite(CODE);
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      ProfileMissingError,
    );
  });

  it('rejects when the joiner is already paired', async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER, 'other-couple');
    await seedInvite(CODE);
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      AlreadyPairedError,
    );
  });

  it('rejects when the creator is already paired', async () => {
    await seedProfile(CREATOR, 'other-couple');
    await seedProfile(JOINER);
    await seedInvite(CODE);
    await expect(joinInvite(db, JOINER, CODE)).rejects.toBeInstanceOf(
      AlreadyPairedError,
    );
  });
});

describe('joinInvite — concurrent race (acceptance criterion)', () => {
  it('two joiners on one code converge on exactly one couple; the loser is consumed', async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER_A);
    await seedProfile(JOINER_B);
    await seedInvite(CODE);

    const results = await Promise.allSettled([
      joinInvite(db, JOINER_A, CODE),
      joinInvite(db, JOINER_B, CODE),
    ]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');
    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect((rejected[0] as PromiseRejectedResult).reason).toBeInstanceOf(
      ConsumedInviteError,
    );

    // Exactly ONE couple exists, and it is the winner's.
    const allCouples = await couples.get();
    expect(allCouples.size).toBe(1);
    const coupleId = allCouples.docs[0].id;
    const winnerCoupleId = (
      fulfilled[0] as PromiseFulfilledResult<{ coupleId: string }>
    ).value.coupleId;
    expect(coupleId).toBe(winnerCoupleId);

    // memberUids is [creator, winning-joiner]; the loser stays unpaired.
    const memberUids = allCouples.docs[0].get('memberUids') as string[];
    expect(memberUids[0]).toBe(CREATOR);
    const winnerJoiner = memberUids[1];
    expect([JOINER_A, JOINER_B]).toContain(winnerJoiner);
    const loser = winnerJoiner === JOINER_A ? JOINER_B : JOINER_A;

    // Both members carry the winner's couple; the loser carries nothing.
    expect((await users.doc(CREATOR).get()).get('coupleId')).toBe(coupleId);
    expect((await users.doc(winnerJoiner).get()).get('coupleId')).toBe(coupleId);
    expect((await users.doc(loser).get()).get('coupleId')).toBeUndefined();

    // The invite is joined by the winner, once.
    const invite = (await invites.doc(CODE).get()).data()!;
    expect(invite.status).toBe('joined');
    expect(invite.joinerUid).toBe(winnerJoiner);
    expect(invite.coupleId).toBe(coupleId);
  });
});

describe('re-issue after join (createInvite guard)', () => {
  it('refuses to re-issue for the now-paired creator and leaves the joined invite untouched', async () => {
    await seedProfile(CREATOR);
    await seedProfile(JOINER);
    await seedInvite(CODE);

    const { coupleId } = await joinInvite(db, JOINER, CODE);
    const joinedBefore = (await invites.doc(CODE).get()).data()!;

    // The creator is now half of a couple: issuing must reject, not resurrect.
    await expect(issueInvite(db, CREATOR)).rejects.toBeInstanceOf(
      CreatorAlreadyPairedError,
    );

    // The joined invite is byte-for-byte unchanged — never back to 'pending'.
    const joinedAfter = (await invites.doc(CODE).get()).data()!;
    expect(joinedAfter.status).toBe('joined');
    expect(joinedAfter.coupleId).toBe(coupleId);
    expect(joinedAfter.joinerUid).toBe(JOINER);
    expect((joinedAfter.joinedAt as Timestamp).toMillis()).toBe(
      (joinedBefore.joinedAt as Timestamp).toMillis(),
    );
  });
});
