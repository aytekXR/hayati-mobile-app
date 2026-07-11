// In-process tests of the RevenueCat webhook HANDLER (method/auth/body-shape/
// error mapping, injected literals — no Firestore) and the SERVICE
// (processRevenueCatEvent against the firestore emulator, no-trigger project).
// The full HTTP wire contract is covered end-to-end in revenuecat-webhook.test.ts.
// Fabricated req/res mirror invite-preview-handler.test.ts.
import type { Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';
import { beforeEach, describe, expect, it } from 'vitest';

import { FREE_SUMMARY, RcEvent } from '../../src/entitlements/entitlement-core';
import { ProcessOutcome, processRevenueCatEvent } from '../../src/entitlements/entitlement-service';
import { makeRevenueCatWebhookHandler } from '../../src/entitlements/revenuecat-webhook';
import { clearNoTriggerFirestore, noTriggerFirestore } from '../support/admin';

// Binds the no-trigger app to the emulator before the service resolves anything.
const db = noTriggerFirestore();

const TOKEN = 'demo-rc-webhook-token';

interface CapturedRes {
  statusCode: number | undefined;
  body: unknown;
  status(code: number): CapturedRes;
  json(payload: unknown): CapturedRes;
}

function fakeRes(): CapturedRes {
  const res: CapturedRes = {
    statusCode: undefined,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
  return res;
}

function fakeReq(overrides: { method?: string; headers?: Record<string, string>; body?: unknown } = {}): Request {
  const headers = overrides.headers ?? {};
  return {
    method: overrides.method ?? 'POST',
    body: overrides.body ?? {},
    // Express req.get is case-insensitive.
    get(name: string): string | undefined {
      return headers[name.toLowerCase()];
    },
  } as unknown as Request;
}

async function invoke(
  handler: ReturnType<typeof makeRevenueCatWebhookHandler>,
  req: Request,
): Promise<CapturedRes> {
  const res = fakeRes();
  await handler(req, res as unknown as Response);
  return res;
}

/** A raw RC envelope body for the handler (which parses req.body itself). */
function envelope(event: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    api_version: '1.0',
    event: {
      type: 'INITIAL_PURCHASE',
      id: 'evt-1',
      event_timestamp_ms: 1_000,
      app_user_id: 'uid-a',
      expiration_at_ms: 9_000,
      ...event,
    },
  };
}

/** A parsed RcEvent for the service tests; overrides replace fields per case. */
function rcEvent(overrides: Partial<RcEvent> = {}): RcEvent {
  return {
    type: 'INITIAL_PURCHASE',
    id: 'evt-1',
    eventTimestampMs: 1_000,
    appUserId: 'uid-a',
    originalAppUserId: null,
    aliases: [],
    environment: 'PRODUCTION',
    store: 'APP_STORE',
    productId: 'premium.monthly',
    newProductId: null,
    periodType: 'NORMAL',
    expirationAtMs: 9_000,
    gracePeriodExpirationAtMs: null,
    entitlementIds: ['premium'],
    ...overrides,
  };
}

function readSubscription(coupleId: string): Promise<FirebaseFirestore.DocumentData | undefined> {
  return db
    .collection('subscriptions')
    .doc(coupleId)
    .get()
    .then((snap) => snap.data());
}

describe('revenueCatWebhook handler — method, auth, body, errors', () => {
  it('rejects a non-POST method with 405', async () => {
    const handler = makeRevenueCatWebhookHandler({ expectedToken: () => TOKEN });
    const res = await invoke(handler, fakeReq({ method: 'GET' }));
    expect(res.statusCode).toBe(405);
    expect(res.body).toEqual({ error: 'method-not-allowed' });
  });

  it('fails closed with 503 when the token is unconfigured (absent)', async () => {
    const handler = makeRevenueCatWebhookHandler({ expectedToken: () => undefined });
    const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN } }));
    expect(res.statusCode).toBe(503);
    expect(res.body).toEqual({ error: 'unconfigured' });
  });

  it('fails closed with 503 when the token is unconfigured (empty string)', async () => {
    const handler = makeRevenueCatWebhookHandler({ expectedToken: () => '' });
    const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN } }));
    expect(res.statusCode).toBe(503);
    expect(res.body).toEqual({ error: 'unconfigured' });
  });

  it('503 unconfigured takes precedence over a bad token (fail-closed first)', async () => {
    const handler = makeRevenueCatWebhookHandler({ expectedToken: () => '' });
    const res = await invoke(handler, fakeReq({ headers: { authorization: 'anything' } }));
    expect(res.statusCode).toBe(503);
  });

  it('rejects a missing Authorization header with 401', async () => {
    const handler = makeRevenueCatWebhookHandler({ expectedToken: () => TOKEN });
    const res = await invoke(handler, fakeReq({ body: envelope() }));
    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: 'unauthorized' });
  });

  it('rejects a wrong token of equal length with 401 (constant-time path)', async () => {
    const handler = makeRevenueCatWebhookHandler({ expectedToken: () => 'abcd' });
    const res = await invoke(handler, fakeReq({ headers: { authorization: 'abce' } }));
    expect(res.statusCode).toBe(401);
  });

  it('rejects a wrong token of different length with 401 (length guard first)', async () => {
    const handler = makeRevenueCatWebhookHandler({ expectedToken: () => 'abcd' });
    const res = await invoke(handler, fakeReq({ headers: { authorization: 'ab' } }));
    expect(res.statusCode).toBe(401);
  });

  it('rejects a valid-JSON body that is not an RC webhook with 400 (never a 500)', async () => {
    let called = false;
    const handler = makeRevenueCatWebhookHandler({
      expectedToken: () => TOKEN,
      process: async () => {
        called = true;
        return { decision: 'noop-type' };
      },
    });
    const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: { not: 'an-event' } }));
    expect(res.statusCode).toBe(400);
    expect(res.body).toEqual({ error: 'malformed' });
    expect(called).toBe(false); // the service is never reached on a shape surprise
  });

  it('maps an applied outcome to 200 processed', async () => {
    const handler = makeRevenueCatWebhookHandler({
      expectedToken: () => TOKEN,
      // db seam injected so the fake process never resolves the (in-process
      // uninitialized) default app; the real getFirestore() path is the e2e's job.
      db: () => db,
      process: async () => ({ decision: 'applied', coupleId: 'c1', uid: 'u1', summary: FREE_SUMMARY }),
    });
    const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: envelope() }));
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'processed', decision: 'applied' });
  });

  it.each<ProcessOutcome['decision']>(['replay-skip', 'stale-skip', 'noop-type', 'unprojectable', 'unresolvable'])(
    'maps a %s outcome to 200 skipped',
    async (decision) => {
      const outcome = { decision } as ProcessOutcome;
      const handler = makeRevenueCatWebhookHandler({
        expectedToken: () => TOKEN,
        db: () => db,
        process: async () => outcome,
      });
      const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: envelope() }));
      expect(res.statusCode).toBe(200);
      expect(res.body).toEqual({ status: 'skipped', decision });
    },
  );

  it('maps a systemic service throw to 500 internal without leaking the message', async () => {
    const handler = makeRevenueCatWebhookHandler({
      expectedToken: () => TOKEN,
      db: () => db,
      process: async () => {
        throw new Error('firestore fell over');
      },
    });
    const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: envelope() }));
    expect(res.statusCode).toBe(500);
    expect(res.body).toEqual({ error: 'internal' });
    expect(JSON.stringify(res.body)).not.toContain('fell over');
  });

  it('reads the expected token at REQUEST time (a late-bound secret needs no redeploy)', async () => {
    // A mutable holder stands in for the late-bound secret env: the seam reads it
    // per request, so the SAME handler flips from 503 to 200 once it is set.
    const secret: { token: string | undefined } = { token: undefined };
    const handler = makeRevenueCatWebhookHandler({
      expectedToken: () => secret.token,
      db: () => db,
      process: async () => ({ decision: 'applied', coupleId: 'c1', uid: 'u1', summary: FREE_SUMMARY }),
    });
    // First request: secret not yet bound → 503.
    const before = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: envelope() }));
    expect(before.statusCode).toBe(503);
    // Secret becomes available; the SAME handler now authorizes it.
    secret.token = TOKEN;
    const after = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: envelope() }));
    expect(after.statusCode).toBe(200);
  });
});

describe('processRevenueCatEvent service (firestore emulator)', () => {
  beforeEach(async () => {
    await clearNoTriggerFirestore();
  });

  async function seedMember(uid: string, coupleId: string): Promise<void> {
    await db.collection('users').doc(uid).set({ coupleId });
  }

  it('one purchase from a member entitles the couple (the shared mirror doc)', async () => {
    await seedMember('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-1');

    const outcome = await processRevenueCatEvent(db, rcEvent({ appUserId: 'uid-a' }));
    expect(outcome).toMatchObject({ decision: 'applied', coupleId: 'couple-1', uid: 'uid-a' });

    const doc = await readSubscription('couple-1');
    expect(doc).toMatchObject({ entitled: true, productId: 'premium.monthly', expiresAtMs: 9_000, willRenew: true });
    expect(doc!.lanes['uid-a']).toMatchObject({ entitled: true, lastEventId: 'evt-1', lastEventTimestampMs: 1_000 });
  });

  it('resolves the couple from EITHER member (the other partner buys)', async () => {
    await seedMember('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-1');

    const outcome = await processRevenueCatEvent(db, rcEvent({ appUserId: 'uid-b', id: 'evt-b' }));
    expect(outcome).toMatchObject({ decision: 'applied', coupleId: 'couple-1', uid: 'uid-b' });
    const doc = await readSubscription('couple-1');
    expect(doc!.entitled).toBe(true);
    expect(doc!.lanes['uid-b']).toBeDefined();
  });

  it('expiry downgrades the couple (entitled true → false)', async () => {
    await seedMember('uid-a', 'couple-1');
    await processRevenueCatEvent(db, rcEvent({ appUserId: 'uid-a', id: 'buy', eventTimestampMs: 100 }));
    expect((await readSubscription('couple-1'))!.entitled).toBe(true);

    const outcome = await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: 'uid-a', id: 'expire', type: 'EXPIRATION', eventTimestampMs: 200, expirationAtMs: 150 }),
    );
    expect(outcome).toMatchObject({ decision: 'applied' });
    expect((await readSubscription('couple-1'))!.entitled).toBe(false);
  });

  it('a replayed event (same order key) is a replay-skip with no doc change', async () => {
    await seedMember('uid-a', 'couple-1');
    await processRevenueCatEvent(db, rcEvent({ appUserId: 'uid-a', id: 'evt-1', eventTimestampMs: 100 }));
    const before = await readSubscription('couple-1');

    const outcome = await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: 'uid-a', id: 'evt-1', eventTimestampMs: 100 }),
    );
    expect(outcome).toMatchObject({ decision: 'replay-skip', coupleId: 'couple-1', uid: 'uid-a' });
    expect(await readSubscription('couple-1')).toEqual(before);
  });

  it('a stale (out-of-order older) event cannot regress the mirror', async () => {
    await seedMember('uid-a', 'couple-1');
    // Newer purchase lands first (ts=200), entitled true.
    await processRevenueCatEvent(db, rcEvent({ appUserId: 'uid-a', id: 'new', eventTimestampMs: 200 }));
    // A late-arriving OLDER expiration (ts=100) must NOT revoke.
    const outcome = await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: 'uid-a', id: 'old', type: 'EXPIRATION', eventTimestampMs: 100, expirationAtMs: 50 }),
    );
    expect(outcome).toMatchObject({ decision: 'stale-skip' });
    expect((await readSubscription('couple-1'))!.entitled).toBe(true);
  });

  it('an unresolvable identity (no user doc) is a counted skip with no write', async () => {
    const outcome = await processRevenueCatEvent(db, rcEvent({ appUserId: 'ghost-user' }));
    expect(outcome).toEqual({ decision: 'unresolvable' });
    expect(await readSubscription('couple-x')).toBeUndefined();
  });

  it('both partners purchasing yields two lanes; the summary picks the later expiry', async () => {
    await seedMember('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-1');
    await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: 'uid-a', id: 'a', eventTimestampMs: 100, productId: 'premium.monthly', expirationAtMs: 5_000 }),
    );
    await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: 'uid-b', id: 'b', eventTimestampMs: 200, productId: 'premium.yearly', expirationAtMs: 9_000 }),
    );

    const doc = await readSubscription('couple-1');
    expect(Object.keys(doc!.lanes).sort()).toEqual(['uid-a', 'uid-b']);
    expect(doc!.entitled).toBe(true);
    expect(doc!.productId).toBe('premium.yearly'); // later expiry wins the display fields
    expect(doc!.expiresAtMs).toBe(9_000);
  });

  it('skips the RC anonymous id and resolves through an alias', async () => {
    await seedMember('uid-a', 'couple-1');
    const outcome = await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: '$RCAnonymousID:deadbeef', aliases: ['uid-a'] }),
    );
    expect(outcome).toMatchObject({ decision: 'applied', coupleId: 'couple-1', uid: 'uid-a' });
  });

  it('falls through a non-existent user doc to the next identity candidate', async () => {
    await seedMember('uid-a', 'couple-1');
    const outcome = await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: 'ghost-user', originalAppUserId: 'uid-a' }),
    );
    expect(outcome).toMatchObject({ decision: 'applied', coupleId: 'couple-1', uid: 'uid-a' });
  });

  it('HARD-STOPS on a real-but-unpaired user, never falling past into an ex-couple alias', async () => {
    // A real user doc WITHOUT coupleId ends the scan — an older alias pointing at
    // an ex-partner's couple must NEVER be resolved (Decision 3 ex-couple hazard).
    await db.collection('users').doc('real-unpaired').set({ displayName: 'Sam' });
    await db.collection('users').doc('ex-alias').set({ coupleId: 'ex-couple' });

    const outcome = await processRevenueCatEvent(
      db,
      rcEvent({ appUserId: 'real-unpaired', aliases: ['ex-alias'] }),
    );
    expect(outcome).toEqual({ decision: 'unresolvable' });
    expect(await readSubscription('ex-couple')).toBeUndefined();
  });

  it('a TEST event is a no-op that never touches Firestore', async () => {
    const outcome = await processRevenueCatEvent(db, rcEvent({ type: 'TEST', appUserId: 'uid-a' }));
    expect(outcome).toEqual({ decision: 'noop-type' });
    expect(await readSubscription('couple-1')).toBeUndefined();
  });

  it('an unprojectable event (non-numeric expiration) is a counted skip, no write', async () => {
    await seedMember('uid-a', 'couple-1');
    const outcome = await processRevenueCatEvent(db, rcEvent({ appUserId: 'uid-a', expirationAtMs: 'soon' }));
    expect(outcome).toEqual({ decision: 'unprojectable' });
    expect(await readSubscription('couple-1')).toBeUndefined();
  });
});
