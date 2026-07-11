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
});
