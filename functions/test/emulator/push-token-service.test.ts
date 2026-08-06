// The Firestore half of ADR-042 Decision 1, against the firestore emulator.
//
// What this suite is for: the cross-document eviction rule, which is the reason
// D1 chose a callable over the documented direct client write. A token is
// device-scoped and a user is not — so when B signs in on the phone A signed out
// of, B's registration must remove that token from A's document. A client can
// never write another user's document under any rule we would accept, so only
// the admin SDK can do it, and only here can it be proven.
//
// Seeded on the NO_TRIGGER project (admin.ts) so nothing here can race a live
// document trigger.
import { Firestore } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { MAX_FCM_TOKENS_PER_USER } from '../../src/notifications/push-token-core';
import { registerPushToken, unregisterPushToken } from '../../src/notifications/push-token-service';
import { fcmTokensOf } from '../../src/notifications/recipients';
import { clearNoTriggerFirestore, noTriggerFirestore } from '../support/admin';

const db: Firestore = noTriggerFirestore();

const A = 'push-a';
const B = 'push-b';
const C = 'push-c';
const PHONE = 'token-shared-phone';

async function seedProfile(uid: string, fcmTokens?: unknown): Promise<void> {
  await db
    .collection('users')
    .doc(uid)
    .set(fcmTokens === undefined ? { displayName: uid } : { displayName: uid, fcmTokens });
}

async function tokensOf(uid: string): Promise<string[]> {
  const snap = await db.collection('users').doc(uid).get();
  return fcmTokensOf(snap.data());
}

beforeEach(async () => {
  await clearNoTriggerFirestore();
});

describe('registerPushToken', () => {
  it('writes the token onto a profile that has none', async () => {
    await seedProfile(A);

    expect(await registerPushToken(db, A, PHONE)).toEqual({ kind: 'ok' });
    expect(await tokensOf(A)).toEqual([PHONE]);
  });

  it('appends alongside an existing token rather than replacing it', async () => {
    await seedProfile(A, ['token-tablet']);

    await registerPushToken(db, A, PHONE);

    expect(await tokensOf(A)).toEqual(['token-tablet', PHONE]);
  });

  it('is idempotent — registering twice leaves one copy', async () => {
    await seedProfile(A);

    await registerPushToken(db, A, PHONE);
    await registerPushToken(db, A, PHONE);

    expect(await tokensOf(A)).toEqual([PHONE]);
  });

  // ADR-042 D1, the decisive argument. Without this, A keeps receiving pushes
  // meant for B, on a phone A no longer holds.
  it('EVICTS the token from every other user document that carries it', async () => {
    await seedProfile(A, [PHONE, 'token-a-tablet']);
    await seedProfile(B);

    expect(await registerPushToken(db, B, PHONE)).toEqual({ kind: 'ok' });

    expect(await tokensOf(B)).toEqual([PHONE]);
    expect(await tokensOf(A)).toEqual(['token-a-tablet']);
    expect(await tokensOf(A)).not.toContain(PHONE);
  });

  it('evicts from MORE than one prior holder — the invariant is global, not pairwise', async () => {
    await seedProfile(A, [PHONE]);
    await seedProfile(B, ['token-b-own', PHONE]);
    await seedProfile(C);

    await registerPushToken(db, C, PHONE);

    expect(await tokensOf(A)).toEqual([]);
    expect(await tokensOf(B)).toEqual(['token-b-own']);
    expect(await tokensOf(C)).toEqual([PHONE]);
  });

  // The eviction must not be a scan that mutates bystanders.
  it('leaves an unrelated user untouched', async () => {
    await seedProfile(A, ['token-a-only']);
    await seedProfile(B);

    await registerPushToken(db, B, PHONE);

    expect(await tokensOf(A)).toEqual(['token-a-only']);
  });

  it('survives a re-registration by the SAME user without self-evicting', async () => {
    await seedProfile(A, [PHONE]);

    expect(await registerPushToken(db, A, PHONE)).toEqual({ kind: 'ok' });

    expect(await tokensOf(A)).toEqual([PHONE]);
  });

  it('caps the array and drops element 0 (ADR-042 D1)', async () => {
    const existing = Array.from({ length: MAX_FCM_TOKENS_PER_USER }, (_, i) => `token-${i}`);
    await seedProfile(A, existing);

    await registerPushToken(db, A, PHONE);

    const stored = await tokensOf(A);
    expect(stored).toHaveLength(MAX_FCM_TOKENS_PER_USER);
    expect(stored).not.toContain('token-0');
    expect(stored[stored.length - 1]).toBe(PHONE);
  });

  it('cleans a junk-bearing stored array on the way past', async () => {
    await seedProfile(A, ['good', '', 42, null]);

    await registerPushToken(db, A, PHONE);

    expect(await tokensOf(A)).toEqual(['good', PHONE]);
  });

  // The update()-not-set(merge) rule from D1: a registration against a profile
  // that does not exist must fail cleanly, never mint an orphan document
  // carrying only fcmTokens.
  it('reports profile-missing and creates NOTHING when there is no profile', async () => {
    expect(await registerPushToken(db, 'no-such-user', PHONE)).toEqual({
      kind: 'profile-missing',
    });

    const snap = await db.collection('users').doc('no-such-user').get();
    expect(snap.exists).toBe(false);
  });
});

describe('unregisterPushToken', () => {
  it('removes the token and leaves the others', async () => {
    await seedProfile(A, ['token-tablet', PHONE]);

    expect(await unregisterPushToken(db, A, PHONE)).toEqual({ kind: 'ok' });

    expect(await tokensOf(A)).toEqual(['token-tablet']);
  });

  it('is a no-op for a token this user does not hold', async () => {
    await seedProfile(A, ['token-tablet']);

    expect(await unregisterPushToken(db, A, PHONE)).toEqual({ kind: 'ok' });

    expect(await tokensOf(A)).toEqual(['token-tablet']);
  });

  it('is idempotent — unregistering twice is still ok', async () => {
    await seedProfile(A, [PHONE]);

    await unregisterPushToken(db, A, PHONE);
    expect(await unregisterPushToken(db, A, PHONE)).toEqual({ kind: 'ok' });

    expect(await tokensOf(A)).toEqual([]);
  });

  // Sign-out cleanup is best-effort by design (D1), so it must never remove a
  // token from anyone but the caller — a client-supplied token is not proof of
  // ownership, and the caller's own document is the only safe blast radius.
  it('touches only the caller, never another holder of the same token', async () => {
    await seedProfile(A, [PHONE]);
    await seedProfile(B, [PHONE]);

    await unregisterPushToken(db, A, PHONE);

    expect(await tokensOf(A)).toEqual([]);
    expect(await tokensOf(B)).toEqual([PHONE]);
  });

  it('reports profile-missing when there is no profile', async () => {
    expect(await unregisterPushToken(db, 'no-such-user', PHONE)).toEqual({
      kind: 'profile-missing',
    });
  });
});

// The property D1 exists to guarantee, stated end to end against real Firestore:
// after any registration, exactly one user document holds that token.
describe('the eviction invariant', () => {
  it('a token is held by exactly one user, after any sequence of registrations', async () => {
    await seedProfile(A);
    await seedProfile(B);
    await seedProfile(C);

    for (const uid of [A, B, C, A, C, B]) {
      await registerPushToken(db, uid, PHONE);

      const holders = (await db.collection('users').get()).docs.filter((doc) =>
        fcmTokensOf(doc.data()).includes(PHONE),
      );
      expect(holders.map((doc) => doc.id)).toEqual([uid]);
    }
  });
});
