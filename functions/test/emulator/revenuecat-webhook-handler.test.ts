// In-process tests of the RevenueCat webhook HANDLER (method/auth/body-shape/
// error mapping, injected literals — no Firestore) and the SERVICE
// (processRevenueCatEvent against the firestore emulator, no-trigger project).
// The full HTTP wire contract is covered end-to-end in revenuecat-webhook.test.ts.
// Fabricated req/res mirror invite-preview-handler.test.ts.
import type { Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';
import { beforeEach, describe, expect, it } from 'vitest';

import { FREE_SUMMARY, RC_ANONYMOUS_PREFIX, RcEvent } from '../../src/entitlements/entitlement-core';
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
    transferredFrom: null,
    transferredTo: null,
    ...overrides,
  };
}

/** A parsed TRANSFER event (ADR-015): no appUserId, transfer arrays instead. */
function transferEvent(overrides: Partial<RcEvent> = {}): RcEvent {
  return rcEvent({
    type: 'TRANSFER',
    id: 'evt-t1',
    eventTimestampMs: 5_000,
    appUserId: null,
    productId: null,
    periodType: null,
    expirationAtMs: undefined,
    entitlementIds: null,
    transferredFrom: ['uid-a'],
    transferredTo: ['uid-b'],
    ...overrides,
  });
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

  // ADR-015: a revoke WROTE the mirror (processed); a hold deliberately wrote
  // nothing (skipped) — and neither is ever a non-200 that would burn RC's budget.
  it('maps a transfer-revoked outcome to 200 processed', async () => {
    const handler = makeRevenueCatWebhookHandler({
      expectedToken: () => TOKEN,
      db: () => db,
      process: async () => ({
        decision: 'transfer-revoked',
        targets: [{ coupleId: 'couple-1', uid: 'uid-a' }],
      }),
    });
    const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: envelope() }));
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'processed', decision: 'transfer-revoked' });
  });

  it('maps a transfer-hold outcome to 200 skipped', async () => {
    const handler = makeRevenueCatWebhookHandler({
      expectedToken: () => TOKEN,
      db: () => db,
      process: async () => ({ decision: 'transfer-hold', reason: 'internal' }),
    });
    const res = await invoke(handler, fakeReq({ headers: { authorization: TOKEN }, body: envelope() }));
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'skipped', decision: 'transfer-hold' });
  });

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

  // --- TRANSFER (M4.3, ADR-015) ---------------------------------------------

  /** Seeds a member and gives their couple an entitled lane (a real purchase). */
  async function seedEntitled(uid: string, coupleId: string): Promise<void> {
    await seedMember(uid, coupleId);
    const applied = await processRevenueCatEvent(
      db,
      rcEvent({ id: `evt-buy-${uid}`, eventTimestampMs: 1_000, appUserId: uid }),
    );
    expect(applied).toMatchObject({ decision: 'applied' });
  }

  // (a) THE false-downgrade regression: a shared-Apple-ID restore INSIDE one
  // couple. The mirror is couple-scoped — the entitlement did not move, only the
  // RC subscriber holding it. Revoking here would strip premium from a paying
  // couple. The doc must be BYTE-unchanged.
  it('(a) a within-couple transfer holds: the mirror is untouched, byte for byte', async () => {
    await seedEntitled('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-1');
    const before = await readSubscription('couple-1');

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: ['uid-a'], transferredTo: ['uid-b'] }),
    );

    expect(outcome).toEqual({ decision: 'transfer-hold', reason: 'internal' });
    expect(await readSubscription('couple-1')).toEqual(before);
  });

  // (b) The only case with positive evidence the entitlement LEFT the couple.
  it('(b) a cross-couple transfer revokes the loser lane and NEVER entitles the gainer', async () => {
    await seedEntitled('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-2');

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: ['uid-a'], transferredTo: ['uid-b'] }),
    );

    expect(outcome).toEqual({
      decision: 'transfer-revoked',
      targets: [{ coupleId: 'couple-1', uid: 'uid-a' }],
    });
    const loser = await readSubscription('couple-1');
    expect(loser).toMatchObject({ entitled: false });
    expect(loser!.lanes['uid-a']).toMatchObject({ entitled: false, expiresAtMs: 5_000 });
    // The gainer's mirror is not even CREATED — a transfer carries no product and
    // no expiry, so there is nothing honest to grant (Decision 1).
    expect(await readSubscription('couple-2')).toBeUndefined();
  });

  it("(b') a sibling lane keeps the loser's couple entitled (lane isolation)", async () => {
    await seedEntitled('uid-a', 'couple-1');
    await seedEntitled('uid-b2', 'couple-1'); // the other partner also bought
    await seedMember('uid-far', 'couple-2');

    await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: ['uid-a'], transferredTo: ['uid-far'] }),
    );

    const doc = await readSubscription('couple-1');
    expect(doc).toMatchObject({ entitled: true });
    expect(doc!.lanes['uid-a'].entitled).toBe(false);
    expect(doc!.lanes['uid-b2'].entitled).toBe(true);
  });

  it('(c) an unplaceable destination (no user doc) holds — the mirror is untouched', async () => {
    await seedEntitled('uid-a', 'couple-1');
    const before = await readSubscription('couple-1');

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: ['uid-a'], transferredTo: ['nobody'] }),
    );

    expect(outcome).toEqual({ decision: 'transfer-hold', reason: 'ambiguous-destination' });
    expect(await readSubscription('couple-1')).toEqual(before);
  });

  // THE reinstall trap: delete app → RC mints an anonymous id → the store
  // auto-restores → only THEN does the app call Purchases.logIn(uid). The
  // destination may be the SAME human. Revoking here strips premium from a
  // paying couple on a reinstall.
  it('(c) an anonymous destination holds — the reinstall false-downgrade trap', async () => {
    await seedEntitled('uid-a', 'couple-1');
    const before = await readSubscription('couple-1');

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({
        transferredFrom: ['uid-a'],
        transferredTo: [`${RC_ANONYMOUS_PREFIX}cafe`],
      }),
    );

    expect(outcome).toEqual({ decision: 'transfer-hold', reason: 'ambiguous-destination' });
    expect(await readSubscription('couple-1')).toEqual(before);
  });

  it("(c') a known-but-unpaired destination is not ambiguous → the revoke fires", async () => {
    await seedEntitled('uid-a', 'couple-1');
    await db.collection('users').doc('uid-solo').set({ displayName: 'no couple' });

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: ['uid-a'], transferredTo: ['uid-solo'] }),
    );

    expect(outcome).toMatchObject({ decision: 'transfer-revoked' });
    expect(await readSubscription('couple-1')).toMatchObject({ entitled: false });
  });

  it('(d) a transfer whose loser resolves to nothing holds and grants nobody', async () => {
    await seedMember('uid-b', 'couple-2');

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: ['ghost'], transferredTo: ['uid-b'] }),
    );

    expect(outcome).toEqual({ decision: 'transfer-hold', reason: 'no-loser' });
    expect(await readSubscription('couple-2')).toBeUndefined();
  });

  // The transfer-arrives-BEFORE-the-purchase-it-moves hazard. The tombstone is
  // written even with no lane present, so the late (older-ts) purchase
  // stale-skips and the moved-away entitlement is never resurrected.
  it('a TRANSFER before the purchase it moves: the late purchase cannot resurrect it', async () => {
    await seedMember('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-2');

    // The transfer lands first (ts 5_000) — no lane exists yet.
    await processRevenueCatEvent(
      db,
      transferEvent({ eventTimestampMs: 5_000, transferredFrom: ['uid-a'], transferredTo: ['uid-b'] }),
    );
    expect(await readSubscription('couple-1')).toMatchObject({ entitled: false });

    // The purchase it moved arrives late, with an OLDER timestamp.
    const late = await processRevenueCatEvent(
      db,
      rcEvent({ id: 'evt-late', eventTimestampMs: 1_000, appUserId: 'uid-a' }),
    );

    expect(late).toMatchObject({ decision: 'stale-skip' });
    expect(await readSubscription('couple-1')).toMatchObject({ entitled: false });
  });

  it('a duplicate TRANSFER is a replay: no second write', async () => {
    await seedEntitled('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-2');
    const event = transferEvent({ transferredFrom: ['uid-a'], transferredTo: ['uid-b'] });

    await processRevenueCatEvent(db, event, { now: () => 111 });
    const first = await readSubscription('couple-1');
    // Re-delivery (RC retries reuse the same id + timestamp) with a DIFFERENT
    // clock: a second write would show up as a changed updatedAtMs.
    await processRevenueCatEvent(db, event, { now: () => 222 });

    expect(await readSubscription('couple-1')).toEqual(first);
    expect(first!.lanes['uid-a'].updatedAtMs).toBe(111);
  });

  it('a STALE transfer cannot re-revoke a lane a newer renewal already advanced', async () => {
    await seedMember('uid-a', 'couple-1');
    await seedMember('uid-b', 'couple-2');
    // A renewal at ts 9_000 (the subscription came back to this couple).
    await processRevenueCatEvent(
      db,
      rcEvent({ id: 'evt-renew', type: 'RENEWAL', eventTimestampMs: 9_000, appUserId: 'uid-a' }),
    );

    // An older transfer (ts 5_000) is finally delivered.
    await processRevenueCatEvent(
      db,
      transferEvent({ eventTimestampMs: 5_000, transferredFrom: ['uid-a'], transferredTo: ['uid-b'] }),
    );

    expect(await readSubscription('couple-1')).toMatchObject({ entitled: true });
  });

  it('a multi-target transfer tombstones every losing couple, and re-delivery is a no-op', async () => {
    await seedEntitled('uid-a', 'couple-1');
    await seedEntitled('uid-c', 'couple-3');
    await seedMember('uid-b', 'couple-2');
    const event = transferEvent({
      transferredFrom: ['uid-a', 'uid-c'],
      transferredTo: ['uid-b'],
    });

    const outcome = await processRevenueCatEvent(db, event, { now: () => 111 });
    expect(outcome).toEqual({
      decision: 'transfer-revoked',
      targets: [
        { coupleId: 'couple-1', uid: 'uid-a' },
        { coupleId: 'couple-3', uid: 'uid-c' },
      ],
    });
    expect(await readSubscription('couple-1')).toMatchObject({ entitled: false });
    expect(await readSubscription('couple-3')).toMatchObject({ entitled: false });

    // Partial-application safety is IDEMPOTENCE, not atomicity: a retry re-runs
    // every target and every one of them replay-skips.
    const before1 = await readSubscription('couple-1');
    const before3 = await readSubscription('couple-3');
    await processRevenueCatEvent(db, event, { now: () => 222 });
    expect(await readSubscription('couple-1')).toEqual(before1);
    expect(await readSubscription('couple-3')).toEqual(before3);
  });

  it('a TRANSFER with no transfer arrays is unprojectable — no doc is created', async () => {
    await seedEntitled('uid-a', 'couple-1');
    const before = await readSubscription('couple-1');

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: null, transferredTo: null }),
    );

    expect(outcome).toEqual({ decision: 'unprojectable' });
    expect(await readSubscription('couple-1')).toEqual(before);
  });

  it('an oversized transfer holds at the gate — zero reads, no writes', async () => {
    await seedEntitled('uid-a', 'couple-1');
    const before = await readSubscription('couple-1');
    const many = Array.from({ length: 11 }, (_unused, i) => `uid-${i}`);

    const outcome = await processRevenueCatEvent(
      db,
      transferEvent({ transferredFrom: ['uid-a', ...many], transferredTo: ['uid-b'] }),
    );

    expect(outcome).toEqual({ decision: 'transfer-hold', reason: 'oversized' });
    expect(await readSubscription('couple-1')).toEqual(before);
  });
});