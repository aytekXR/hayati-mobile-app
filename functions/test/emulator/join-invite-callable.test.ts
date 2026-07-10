// End-to-end callable test through the FUNCTIONS emulator: real HTTP callable
// protocol, real (emulator-minted, unsigned) idToken verification, real reads +
// transactional writes into the firestore emulator. Requires all three
// emulators:
//   firebase emulators:exec --only auth,firestore,functions \
//     --project demo-hayati 'cd functions && npm run test:ci'
import { Timestamp } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { FUNCTIONS_REGION } from '../../src/invites/create-invite';
import {
  EMULATOR_PROJECT_ID,
  adminFirestore,
  clearFirestoreData,
} from '../support/admin';

// emulators:exec injects hosts for auth/firestore but not functions (see
// create-invite-callable.test.ts) — the callable URL is derived from
// firebase.json's pinned emulator port.
const FUNCTIONS_EMULATOR_ORIGIN = 'http://127.0.0.1:5001';
const JOIN_URL = `${FUNCTIONS_EMULATOR_ORIGIN}/${EMULATOR_PROJECT_ID}/${FUNCTIONS_REGION}/joinInvite`;

const db = adminFirestore();
const invites = db.collection('invites');
const users = db.collection('users');

const CODE = 'AAAA2222';

function requireAuthEmulator(): string {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!host) {
    throw new Error(
      'This suite needs the auth emulator (see file header for the command).',
    );
  }
  return host;
}

/** Mints a fresh anonymous user on the auth emulator; returns its idToken + uid. */
async function signUpUser(): Promise<{ idToken: string; localId: string }> {
  const host = requireAuthEmulator();
  const response = await fetch(
    `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-emulator-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  expect(response.ok).toBe(true);
  return (await response.json()) as { idToken: string; localId: string };
}

const PROFILE = {
  status: 'married',
  contentLanguage: 'tr',
  register: 'respectful',
  createdAt: Timestamp.now(),
};

/** Seeds a users/{uid} profile (optionally already paired). */
function seedProfile(uid: string, coupleId?: string): Promise<unknown> {
  return users.doc(uid).set(
    coupleId === undefined ? PROFILE : { ...PROFILE, coupleId },
  );
}

/** Seeds a pending invite for `creatorUid` with field overrides. */
function seedInvite(
  creatorUid: string,
  overrides: Record<string, unknown> = {},
): Promise<unknown> {
  return invites.doc(CODE).set({
    creatorUid,
    status: 'pending',
    expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    createdAt: Timestamp.now(),
    ...overrides,
  });
}

function callJoin(idToken: string | undefined, data: unknown): Promise<Response> {
  return fetch(JOIN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken === undefined ? {} : { Authorization: `Bearer ${idToken}` }),
      // No X-Firebase-AppCheck header: the M1.3 posture (enforcement OFF) means
      // calls without attestation must pass.
    },
    body: JSON.stringify({ data }),
  });
}

interface CallableError {
  error: { status: string; message: string; details?: { reason?: string } };
}

beforeAll(async () => {
  const ping = await fetch(FUNCTIONS_EMULATOR_ORIGIN).catch(() => null);
  if (ping === null) {
    throw new Error(
      `Functions emulator not reachable at ${FUNCTIONS_EMULATOR_ORIGIN}. ` +
        'Did you run this via firebase emulators:exec (with functions built)?',
    );
  }
});

beforeEach(async () => {
  await clearFirestoreData();
});

describe('joinInvite callable (functions emulator)', () => {
  it('pairs two signed-in users and returns the coupleId', async () => {
    const creator = await signUpUser();
    const joiner = await signUpUser();
    await seedProfile(creator.localId);
    await seedProfile(joiner.localId);
    await seedInvite(creator.localId);

    const response = await callJoin(joiner.idToken, {
      code: CODE,
      timezone: 'Asia/Riyadh',
    });
    expect(response.status).toBe(200);
    const { result } = (await response.json()) as {
      result: { coupleId: string };
    };
    expect(typeof result.coupleId).toBe('string');

    const couple = (
      await db.collection('couples').doc(result.coupleId).get()
    ).data()!;
    expect(couple.memberUids).toEqual([creator.localId, joiner.localId]);
    expect(couple.timezone).toBe('Asia/Riyadh');
    expect((await users.doc(joiner.localId).get()).get('coupleId')).toBe(
      result.coupleId,
    );
  });

  it('rejects unauthenticated calls with UNAUTHENTICATED', async () => {
    const response = await callJoin(undefined, { code: CODE });
    expect(response.status).toBe(401);
    expect(((await response.json()) as CallableError).error.status).toBe(
      'UNAUTHENTICATED',
    );
  });

  it('rejects a non-string code with INVALID_ARGUMENT', async () => {
    const joiner = await signUpUser();
    const response = await callJoin(joiner.idToken, { code: 42 });
    expect(response.status).toBe(400);
    expect(((await response.json()) as CallableError).error.status).toBe(
      'INVALID_ARGUMENT',
    );
  });

  it("surfaces an unknown code as NOT_FOUND / reason 'unknown'", async () => {
    const joiner = await signUpUser();
    await seedProfile(joiner.localId);
    const response = await callJoin(joiner.idToken, { code: 'ZZZZ9999' });
    expect(response.status).toBe(404);
    const body = (await response.json()) as CallableError;
    expect(body.error.status).toBe('NOT_FOUND');
    expect(body.error.details?.reason).toBe('unknown');
  });

  it("surfaces an expired invite as FAILED_PRECONDITION / reason 'expired'", async () => {
    const creator = await signUpUser();
    const joiner = await signUpUser();
    await seedInvite(creator.localId, { status: 'expired' });
    const response = await callJoin(joiner.idToken, { code: CODE });
    expect(response.status).toBe(400);
    const body = (await response.json()) as CallableError;
    expect(body.error.status).toBe('FAILED_PRECONDITION');
    expect(body.error.details?.reason).toBe('expired');
  });

  it("surfaces a self-join as FAILED_PRECONDITION / reason 'self-join'", async () => {
    const creator = await signUpUser();
    await seedInvite(creator.localId);
    const response = await callJoin(creator.idToken, { code: CODE });
    expect(response.status).toBe(400);
    const body = (await response.json()) as CallableError;
    expect(body.error.status).toBe('FAILED_PRECONDITION');
    expect(body.error.details?.reason).toBe('self-join');
  });

  it("surfaces an already-paired joiner as FAILED_PRECONDITION / reason 'already-paired'", async () => {
    const creator = await signUpUser();
    const joiner = await signUpUser();
    await seedProfile(creator.localId);
    await seedProfile(joiner.localId, 'some-existing-couple');
    await seedInvite(creator.localId);
    const response = await callJoin(joiner.idToken, { code: CODE });
    expect(response.status).toBe(400);
    const body = (await response.json()) as CallableError;
    expect(body.error.status).toBe('FAILED_PRECONDITION');
    expect(body.error.details?.reason).toBe('already-paired');
  });

  it('resolves a concurrent race to one ok + one consumed rejection', async () => {
    const creator = await signUpUser();
    const joinerA = await signUpUser();
    const joinerB = await signUpUser();
    await seedProfile(creator.localId);
    await seedProfile(joinerA.localId);
    await seedProfile(joinerB.localId);
    await seedInvite(creator.localId);

    const [first, second] = await Promise.all([
      callJoin(joinerA.idToken, { code: CODE }),
      callJoin(joinerB.idToken, { code: CODE }),
    ]);
    const statuses = [first.status, second.status].sort();
    // Exactly one 200 and one 400 (FAILED_PRECONDITION / consumed).
    expect(statuses).toEqual([200, 400]);

    const loser = first.status === 400 ? first : second;
    const body = (await loser.json()) as CallableError;
    expect(body.error.status).toBe('FAILED_PRECONDITION');
    expect(body.error.details?.reason).toBe('consumed');

    // Drain the winner's body so its socket is reused.
    await (first.status === 200 ? first : second).json();

    const allCouples = await db.collection('couples').get();
    expect(allCouples.size).toBe(1);
  });
});
