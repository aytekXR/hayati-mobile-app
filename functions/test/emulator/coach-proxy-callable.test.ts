// End-to-end coachProxy test through the FUNCTIONS emulator (ADR-016 test
// commitment 8): real callable HTTP protocol, real (emulator-minted, unsigned)
// idToken verification, real Firestore reads. Requires all three emulators:
//   firebase emulators:exec --only auth,firestore,functions \
//     --project demo-hayati 'cd functions && npm run test:ci'
//
// CAREFUL: the DEPLOYED default provider is UnconfiguredCoachProvider (fail-closed)
// — this slice makes ZERO live model calls anywhere. So the e2e proves the honest
// deploy posture, not a persona round-trip:
//   - a valid premium + within-cap turn → `unavailable` (the unconfigured provider
//     throws; the reserved cap is refunded);
//   - a crisis message → 200 help path — the safety accept line end-to-end, which
//     works EVEN unconfigured (the pre-scan precedes any provider/gate);
//   - a sentinel in the request never echoes back in the response.
//
// The emulator PROCESS's stdout is not capturable from this test; the framework's
// own error-logging perimeter is instead pinned in coach-proxy-handler.test.ts by
// the "no non-HttpsError ever escapes the handler" assertions (a non-HttpsError
// escape is exactly what would trigger the callable framework's https.js
// auto-logging of message + stack). Here we assert the observable perimeter: the
// response body never carries the sentinel.
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { FUNCTIONS_REGION } from '../../src/invites/create-invite';
import { EMULATOR_PROJECT_ID, adminFirestore, clearFirestoreData } from '../support/admin';

const FUNCTIONS_EMULATOR_ORIGIN = 'http://127.0.0.1:5001';
const CALLABLE_URL = `${FUNCTIONS_EMULATOR_ORIGIN}/${EMULATOR_PROJECT_ID}/${FUNCTIONS_REGION}/coachProxy`;

const SENTINEL = 'HAYATI_SENTINEL_7f3a';

const db = adminFirestore();

function requireAuthEmulator(): string {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!host) {
    throw new Error('This suite needs the auth emulator (see file header for the command).');
  }
  return host;
}

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

function callCoach(idToken: string | undefined, data: unknown): Promise<Response> {
  return fetch(CALLABLE_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken === undefined ? {} : { Authorization: `Bearer ${idToken}` }),
    },
    body: JSON.stringify({ data }),
  });
}

function coachData(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    coupleId: 'couple-1',
    personaId: 'coach',
    language: 'tr',
    register: 'tr-playful',
    messages: [{ role: 'user', text: 'merhaba nasilsin bugun' }],
    ...overrides,
  };
}

/** Seeds a couple (with `uid` a member) and a valid, future-dated premium mirror. */
async function seedPremiumCouple(uid: string): Promise<void> {
  await db.collection('couples').doc('couple-1').set({
    memberUids: [uid],
    timezone: 'Europe/Istanbul',
  });
  await db.collection('subscriptions').doc('couple-1').set({
    entitled: true,
    expiresAtMs: Date.now() + 10_000_000_000,
  });
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

describe('coachProxy callable (functions emulator, default fail-closed wiring)', () => {
  it('rejects an unauthenticated call with UNAUTHENTICATED', async () => {
    const response = await callCoach(undefined, coachData());
    expect(response.status).toBe(401);
    const body = (await response.json()) as { error: { status: string } };
    expect(body.error.status).toBe('UNAUTHENTICATED');
  });

  it('a valid premium + within-cap turn → UNAVAILABLE (the unconfigured provider, honest deploy posture)', async () => {
    const { idToken, localId } = await signUpUser();
    await seedPremiumCouple(localId);

    const response = await callCoach(idToken, coachData());
    expect(response.status).toBe(503);
    const body = (await response.json()) as { error: { status: string } };
    expect(body.error.status).toBe('UNAVAILABLE');

    // The reserved unit was refunded on the provider failure (Decision 2/7).
    const daily = await db
      .collection('coachUsage')
      .doc('couple-1')
      .collection('daily')
      .doc(localId)
      .get();
    expect(daily.data()!.count).toBe(0);
  });

  it('a crisis message → 200 help path (works even unconfigured — the safety accept line e2e)', async () => {
    const { idToken } = await signUpUser();
    // No couple / subscription seeded: the pre-scan precedes gating, so the help
    // path is served to ANY authenticated caller.
    const response = await callCoach(idToken, coachData({ messages: [{ role: 'user', text: 'intihar' }] }));
    expect(response.status).toBe(200);
    const body = (await response.json()) as { result: { kind: string; category: string; text: string } };
    expect(body.result.kind).toBe('help');
    expect(body.result.category).toBe('selfHarm');
    expect(body.result.text.length).toBeGreaterThan(0);
  });

  it('a sentinel in the request is never echoed back in the response body', async () => {
    const { idToken } = await signUpUser();
    const response = await callCoach(
      idToken,
      coachData({ messages: [{ role: 'user', text: `intihar ${SENTINEL}` }] }),
    );
    expect(response.status).toBe(200);
    const raw = await response.text();
    expect(raw).not.toContain(SENTINEL); // the static help copy never carries input text
    expect((JSON.parse(raw) as { result: { kind: string } }).result.kind).toBe('help');
  });
});
