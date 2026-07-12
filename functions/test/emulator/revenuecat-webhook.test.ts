// End-to-end test of the revenueCatWebhook HTTP endpoint through the FUNCTIONS
// emulator: real HTTP POST, real token check against functions/.env.demo-hayati,
// real identity resolution + mirror write on the firestore emulator. Requires
// all three emulators (auth is unused but the shared exec starts it):
//   firebase emulators:exec --only auth,firestore,functions \
//     --project demo-hayati 'cd functions && npm run test:ci'
// The handler/service unit surface is covered in revenuecat-webhook-handler.test.ts;
// this asserts the wire contract the dashboard webhook will hit.
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { FUNCTIONS_REGION } from '../../src/invites/create-invite';
import { EMULATOR_PROJECT_ID, adminFirestore, clearFirestoreData } from '../support/admin';

const FUNCTIONS_EMULATOR_ORIGIN = 'http://127.0.0.1:5001';
const WEBHOOK_URL = `${FUNCTIONS_EMULATOR_ORIGIN}/${EMULATOR_PROJECT_ID}/${FUNCTIONS_REGION}/revenueCatWebhook`;

// Matches functions/.env.demo-hayati (loaded by the emulator as demo-hayati).
const TOKEN = 'demo-rc-webhook-token';

const db = adminFirestore();

function post(body: unknown, token: string | undefined, raw = false): Promise<Response> {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (token !== undefined) {
    headers.authorization = token;
  }
  return fetch(WEBHOOK_URL, {
    method: 'POST',
    headers,
    body: raw ? (body as string) : JSON.stringify(body),
  });
}

function envelope(event: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    api_version: '1.0',
    event: {
      type: 'INITIAL_PURCHASE',
      id: 'evt-e2e-1',
      event_timestamp_ms: 1_700_000_000_000,
      app_user_id: 'uid-e2e-a',
      environment: 'SANDBOX',
      store: 'APP_STORE',
      product_id: 'premium.monthly',
      period_type: 'NORMAL',
      expiration_at_ms: 1_700_000_900_000,
      entitlement_ids: ['premium'],
      ...event,
    },
  };
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

describe('revenueCatWebhook (functions emulator)', () => {
  it('rejects a wrong token with 401', async () => {
    const response = await post(envelope(), 'not-the-token');
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: 'unauthorized' });
  });

  it('rejects a missing token with 401', async () => {
    const response = await post(envelope(), undefined);
    expect(response.status).toBe(401);
  });

  it('processes a real INITIAL_PURCHASE and mirrors it onto subscriptions/{coupleId}', async () => {
    await db.collection('users').doc('uid-e2e-a').set({ coupleId: 'couple-e2e' });

    const response = await post(envelope(), TOKEN);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: 'processed', decision: 'applied' });

    const doc = (await db.collection('subscriptions').doc('couple-e2e').get()).data();
    expect(doc).toMatchObject({
      entitled: true,
      productId: 'premium.monthly',
      expiresAtMs: 1_700_000_900_000,
      environment: 'SANDBOX',
    });
    expect(doc!.lanes['uid-e2e-a']).toMatchObject({ entitled: true, lastEventId: 'evt-e2e-1' });
  });

  it('returns 200 skipped for an authenticated but unresolvable purchase (no user doc)', async () => {
    const response = await post(envelope({ app_user_id: 'uid-no-doc' }), TOKEN);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: 'skipped', decision: 'unresolvable' });
  });

  it('rejects a valid-JSON body that is not an RC webhook with an explicit 400 malformed', async () => {
    const response = await post({ hello: 'world' }, TOKEN);
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: 'malformed' });
  });

  it('rejects a syntactically invalid JSON body with 400 (framework body parser)', async () => {
    const response = await post('{ not valid json', TOKEN, true);
    expect(response.status).toBe(400);
  });

  // THE Finding-0 wire proof (ADR-015): RC's REAL transfer body carries NO
  // app_user_id. Before M4.3 the envelope contract rejected it as malformed and
  // the endpoint answered 400 — RC would retry 5x over ~155 min and then DROP the
  // event permanently. Body shape is RC's documented sample, verbatim.
  it('accepts a REAL TRANSFER body (no app_user_id) over the wire and revokes the loser', async () => {
    await db.collection('users').doc('uid-loser').set({ coupleId: 'couple-loser' });
    await db.collection('users').doc('uid-gainer').set({ coupleId: 'couple-gainer' });
    // The loser's couple is entitled from a real purchase.
    await post(
      envelope({ id: 'evt-buy-wire', app_user_id: 'uid-loser', event_timestamp_ms: 1_000 }),
      TOKEN,
    );
    expect((await db.collection('subscriptions').doc('couple-loser').get()).get('entitled')).toBe(true);

    const res = await post(
      {
        api_version: '1.0',
        event: {
          type: 'TRANSFER',
          id: 'evt-transfer-wire',
          event_timestamp_ms: 5_000,
          store: 'APP_STORE',
          environment: 'SANDBOX',
          transferred_from: ['uid-loser'],
          transferred_to: ['uid-gainer'],
        },
      },
      TOKEN,
    );

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: 'processed', decision: 'transfer-revoked' });
    // The loser is downgraded; the gainer's mirror is never even created (a
    // TRANSFER carries no product/expiry, so it can never entitle anyone).
    const loser = await db.collection('subscriptions').doc('couple-loser').get();
    expect(loser.get('entitled')).toBe(false);
    expect((await db.collection('subscriptions').doc('couple-gainer').get()).exists).toBe(false);
  });
});