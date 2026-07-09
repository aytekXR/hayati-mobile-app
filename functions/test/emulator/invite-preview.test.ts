// End-to-end test of the zero-auth invitePreview HTTP endpoint through the
// FUNCTIONS emulator: real HTTP (plain GET, no callable envelope), real reads
// from the firestore emulator, real display-name lookup from the auth emulator.
// Requires all three emulators:
//   firebase emulators:exec --only auth,firestore,functions \
//     --project demo-hayati 'cd functions && npm run test:ci'
import { getAuth } from 'firebase-admin/auth';
import { Timestamp } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { FUNCTIONS_REGION } from '../../src/invites/create-invite';
import { PREVIEW_RATE_LIMIT } from '../../src/invites/invite-preview';
import {
  EMULATOR_PROJECT_ID,
  adminFirestore,
  clearFirestoreData,
} from '../support/admin';

// emulators:exec injects auth/firestore hosts but not the functions host
// (see create-invite-callable.test.ts) — so the URL is derived from
// firebase.json's pinned port.
const FUNCTIONS_EMULATOR_ORIGIN = 'http://127.0.0.1:5001';
const PREVIEW_URL = `${FUNCTIONS_EMULATOR_ORIGIN}/${EMULATOR_PROJECT_ID}/${FUNCTIONS_REGION}/invitePreview`;

const db = adminFirestore();
const invites = db.collection('invites');

// Distinct valid-format codes (alphabet A/B/C + digits 2-6) per case.
const CODE_NAMED = 'AAAA2222';
const CODE_ANON = 'BBBB3333';
const CODE_EXPIRED_STATUS = 'CCCC4444';
const CODE_EXPIRED_PAST = 'DDDD5555';
const CODE_ABSENT = 'EEEE6666';
const CODE_JOINED = 'FFFF7777';
const MALFORMED = 'not-a-code';

function seedInvite(
  code: string,
  data: Record<string, unknown>,
): Promise<FirebaseFirestore.WriteResult> {
  return invites.doc(code).set({ createdAt: Timestamp.now(), ...data });
}

/** Idempotent across re-runs: recreate the auth user so uid collisions can't fail. */
async function putCreator(uid: string, displayName?: string): Promise<void> {
  await getAuth()
    .deleteUser(uid)
    .catch(() => undefined);
  await getAuth().createUser(
    displayName === undefined ? { uid } : { uid, displayName },
  );
}

function getPreview(code: string): Promise<Response> {
  return fetch(`${PREVIEW_URL}?code=${encodeURIComponent(code)}`);
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

describe('invitePreview (functions emulator)', () => {
  it('valid pending code with a named creator returns status + creatorDisplayName only', async () => {
    const creatorUid = 'creator-named-uid';
    await putCreator(creatorUid, 'Amir');
    await seedInvite(CODE_NAMED, {
      creatorUid,
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });

    const response = await getPreview(CODE_NAMED);
    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;

    expect(body).toEqual({ status: 'valid', creatorDisplayName: 'Amir' });
    // Field-surface invariant: EXACTLY the documented keys, and never the uid.
    expect(Object.keys(body).sort()).toEqual(['creatorDisplayName', 'status']);
    expect(JSON.stringify(body)).not.toContain(creatorUid);
  });

  it('valid pending code with a creator that has no displayName returns status only', async () => {
    const creatorUid = 'creator-anon-uid';
    await putCreator(creatorUid); // exists, but no display name set
    await seedInvite(CODE_ANON, {
      creatorUid,
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });

    const response = await getPreview(CODE_ANON);
    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;

    expect(body).toEqual({ status: 'valid' });
    expect(Object.keys(body).sort()).toEqual(['status']);
    expect(JSON.stringify(body)).not.toContain(creatorUid);
  });

  it("a doc already marked 'expired' returns status 'expired' only", async () => {
    const creatorUid = 'creator-expired-uid';
    await seedInvite(CODE_EXPIRED_STATUS, {
      creatorUid,
      status: 'expired',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });

    const response = await getPreview(CODE_EXPIRED_STATUS);
    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;

    expect(body).toEqual({ status: 'expired' });
    expect(Object.keys(body).sort()).toEqual(['status']);
    expect(JSON.stringify(body)).not.toContain(creatorUid);
  });

  it("a pending doc past its expiry returns 'expired' and is NOT mutated (read-only)", async () => {
    const creatorUid = 'creator-past-uid';
    await seedInvite(CODE_EXPIRED_PAST, {
      creatorUid,
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() - 1),
    });

    const response = await getPreview(CODE_EXPIRED_PAST);
    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;
    expect(body).toEqual({ status: 'expired' });
    expect(Object.keys(body).sort()).toEqual(['status']);

    // The zero-auth path must never amplify writes: the doc still reads
    // 'pending' (createInvite owns lazy expiry, not this endpoint).
    const after = await invites.doc(CODE_EXPIRED_PAST).get();
    expect(after.data()!.status).toBe('pending');
  });

  it("an absent code returns 'unknown'", async () => {
    const response = await getPreview(CODE_ABSENT);
    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;
    expect(body).toEqual({ status: 'unknown' });
    expect(Object.keys(body).sort()).toEqual(['status']);
  });

  it("a malformed code returns 'unknown'", async () => {
    const response = await getPreview(MALFORMED);
    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;
    expect(body).toEqual({ status: 'unknown' });
    expect(Object.keys(body).sort()).toEqual(['status']);
  });

  it("a 'joined' invite previews as uniform 'expired' (no consumed oracle)", async () => {
    // M2.3 added the terminal 'joined' status; preview is UNCHANGED — a joined
    // invite is not 'pending', so it reports the uniform 'expired' surface, the
    // same as a stale or non-existent code (a joiner who already paired learns
    // nothing extra). The field surface stays exactly {status}.
    const creatorUid = 'creator-joined-uid';
    await seedInvite(CODE_JOINED, {
      creatorUid,
      status: 'joined',
      coupleId: 'couple-xyz',
      joinerUid: 'some-joiner',
      // Future expiresAt proves the join status — not the clock — drives this.
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });

    const response = await getPreview(CODE_JOINED);
    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;
    expect(body).toEqual({ status: 'expired' });
    expect(Object.keys(body).sort()).toEqual(['status']);
    expect(JSON.stringify(body)).not.toContain('couple-xyz');
  });

  it('a missing code param returns 400 missing-code', async () => {
    const response = await fetch(PREVIEW_URL);
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: 'missing-code' });
  });

  it('a non-GET method returns 405 method-not-allowed', async () => {
    const response = await fetch(`${PREVIEW_URL}?code=${CODE_ABSENT}`, {
      method: 'POST',
    });
    expect(response.status).toBe(405);
    expect(await response.json()).toEqual({ error: 'method-not-allowed' });
  });

  // MUST be last: the per-IP limiter is shared per functions-emulator instance
  // and is not resettable between tests, so this exhausts the window. Firing
  // 2*LIMIT+1 is window-split-proof — even if the burst straddles a window
  // boundary the allowance is at most 2*LIMIT, so at least one is rejected.
  // Fired SEQUENTIALLY: 60+ concurrent requests overwhelm the emulator's
  // per-request worker loading (and concurrency is irrelevant to the count
  // that makes this window-split-proof).
  it('rate-limits a burst from one IP with 429 rate-limited', async () => {
    const burst = 2 * PREVIEW_RATE_LIMIT + 1;
    let limitedBody: unknown;
    let limitedCount = 0;
    for (let i = 0; i < burst; i += 1) {
      const response = await getPreview(CODE_ABSENT);
      if (response.status === 429) {
        limitedCount += 1;
        limitedBody ??= await response.json();
      } else {
        await response.json(); // drain the body so the socket is reused
      }
    }

    expect(limitedCount).toBeGreaterThanOrEqual(1);
    expect(limitedBody).toEqual({ error: 'rate-limited' });
  });
});
