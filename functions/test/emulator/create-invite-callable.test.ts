// End-to-end callable test through the FUNCTIONS emulator: real HTTP callable
// protocol, real (emulator-minted, unsigned) idToken verification, real write
// into the firestore emulator. Requires all three emulators:
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

// emulators:exec injects hosts for auth/firestore but deliberately not for
// functions (verified against firebase-tools 15.22.4 source: its
// setEnvVarsForEmulators has no FUNCTIONS case) — so the callable URL is
// derived from firebase.json's pinned emulator port.
const FUNCTIONS_EMULATOR_ORIGIN = 'http://127.0.0.1:5001';
const CALLABLE_URL = `${FUNCTIONS_EMULATOR_ORIGIN}/${EMULATOR_PROJECT_ID}/${FUNCTIONS_REGION}/createInvite`;

const db = adminFirestore();

function requireAuthEmulator(): string {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!host) {
    throw new Error(
      'This suite needs the auth emulator (see file header for the command).',
    );
  }
  return host;
}

/** Mints a fresh anonymous user on the auth emulator; returns its idToken. */
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
  const body = (await response.json()) as { idToken: string; localId: string };
  return body;
}

/** Since ADR-019, issuing requires the caller's profile to exist. */
function seedProfile(uid: string): Promise<unknown> {
  return db.collection('users').doc(uid).set({
    status: 'married',
    contentLanguage: 'tr',
    register: 'respectful',
    createdAt: Timestamp.now(),
  });
}

function callCreateInvite(idToken?: string): Promise<Response> {
  return fetch(CALLABLE_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken === undefined
        ? {}
        : { Authorization: `Bearer ${idToken}` }),
      // NOTE: no X-Firebase-AppCheck header anywhere in this suite — the M1.3
      // posture (enforcement OFF) means calls without attestation must pass.
    },
    body: JSON.stringify({ data: {} }),
  });
}

beforeAll(async () => {
  // Fail fast with a readable message if the functions emulator isn't up.
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

describe('createInvite callable (functions emulator)', () => {
  it('rejects unauthenticated calls with UNAUTHENTICATED', async () => {
    const response = await callCreateInvite();
    expect(response.status).toBe(401);
    const body = (await response.json()) as {
      error: { status: string };
    };
    expect(body.error.status).toBe('UNAUTHENTICATED');
  });

  it('rejects a present-but-garbage bearer token', async () => {
    // The functions EMULATOR skips real token verification
    // (FIREBASE_DEBUG_MODE → unsafeDecodeIdToken), so 'not-a-jwt' reaches the
    // handler as auth with uid undefined — production rejects it earlier, in
    // checkAuthToken. This asserts the handler's own uid guard catches it.
    const response = await callCreateInvite('not-a-jwt');
    expect(response.status).toBe(401);
    const body = (await response.json()) as { error: { status: string } };
    expect(body.error.status).toBe('UNAUTHENTICATED');
  });

  it('issues a code for a signed-in caller and lands the invite in Firestore', async () => {
    const { idToken, localId } = await signUpUser();
    await seedProfile(localId);

    const response = await callCreateInvite(idToken);
    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      result: { code: string; expiresAtMillis: number; reused: boolean };
    };
    expect(body.result.code).toMatch(/^[A-Z2-9]{8}$/);
    expect(body.result.reused).toBe(false);
    expect(body.result.expiresAtMillis).toBeGreaterThan(Date.now());

    const doc = await db.collection('invites').doc(body.result.code).get();
    expect(doc.exists).toBe(true);
    expect(doc.data()!.creatorUid).toBe(localId);
    expect(doc.data()!.status).toBe('pending');
  });

  it('a second (even concurrent) call for the same caller returns the same code', async () => {
    const { idToken, localId } = await signUpUser();
    await seedProfile(localId);

    const [first, second] = await Promise.all([
      callCreateInvite(idToken),
      callCreateInvite(idToken),
    ]);
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    const a = ((await first.json()) as { result: { code: string } }).result;
    const b = ((await second.json()) as { result: { code: string } }).result;
    expect(a.code).toBe(b.code);

    const third = await callCreateInvite(idToken);
    const c = (
      (await third.json()) as { result: { code: string; reused: boolean } }
    ).result;
    expect(c.code).toBe(a.code);
    expect(c.reused).toBe(true);
  });

  it("refuses to issue for an already-paired creator (FAILED_PRECONDITION / 'already-paired')", async () => {
    // M2.3: once the caller is half of a couple, createInvite rejects with the
    // same already-paired surface as joinInvite (one reason across both
    // callables). The join Function is the only writer of coupleId; here we
    // seed a paired profile with the admin SDK to stand in for a prior join.
    const { idToken, localId } = await signUpUser();
    await db.collection('users').doc(localId).set({
      status: 'married',
      contentLanguage: 'tr',
      register: 'respectful',
      coupleId: 'some-existing-couple',
      createdAt: Timestamp.now(),
    });

    const response = await callCreateInvite(idToken);
    expect(response.status).toBe(400);
    const body = (await response.json()) as {
      error: { status: string; details?: { reason?: string } };
    };
    expect(body.error.status).toBe('FAILED_PRECONDITION');
    expect(body.error.details?.reason).toBe('already-paired');
  });
});
