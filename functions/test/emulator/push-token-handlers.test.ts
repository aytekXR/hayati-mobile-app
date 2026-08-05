// In-process tests of the ADR-042 D1 callable HANDLERS: the auth guard, the
// request validation, the typed-outcome → HttpsError mapping, and the one
// commitment specific to this pair — that neither the token nor the uid can reach
// a log line or an error payload. Exercised against the firestore emulator; the
// default admin app binds to demo-hayati.
import { HttpsError } from 'firebase-functions/v2/https';
import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  makeRegisterPushTokenHandler,
  makeUnregisterPushTokenHandler,
} from '../../src/notifications/push-token';
import { fcmTokensOf } from '../../src/notifications/recipients';
import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();

const UID = 'pt-uid';
const TOKEN = 'pt-device-token';

function req(uid: string | undefined, data: unknown): CallableRequest {
  return { auth: uid === undefined ? undefined : { uid }, data } as unknown as CallableRequest;
}

async function expectHttpsError(run: Promise<unknown>, code: string): Promise<HttpsError> {
  const error = await run.then(
    () => {
      throw new Error(`expected HttpsError '${code}' but the call succeeded`);
    },
    (thrown) => thrown as unknown,
  );
  expect(error).toBeInstanceOf(HttpsError);
  expect((error as HttpsError).code).toBe(code);
  return error as HttpsError;
}

async function seedProfile(): Promise<void> {
  await db.collection('users').doc(UID).set({ displayName: 'pt' });
}

async function storedTokens(): Promise<string[]> {
  return fcmTokensOf((await db.collection('users').doc(UID).get()).data());
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('registerPushToken handler', () => {
  it('rejects unauthenticated callers', async () => {
    await expectHttpsError(
      makeRegisterPushTokenHandler()(req(undefined, { token: TOKEN })),
      'unauthenticated',
    );
  });

  it('rejects a malformed request with invalid-argument and a shape-only reason', async () => {
    const handler = makeRegisterPushTokenHandler();
    const error = await expectHttpsError(handler(req(UID, {})), 'invalid-argument');
    expect(error.details).toEqual({ reason: 'bad-request' });

    await expectHttpsError(handler(req(UID, { token: 42 })), 'invalid-argument');
    await expectHttpsError(handler(req(UID, { token: '' })), 'invalid-argument');
    await expectHttpsError(handler(req(UID, null)), 'invalid-argument');
  });

  it('maps an absent profile to failed-precondition, and writes nothing', async () => {
    const handler = makeRegisterPushTokenHandler();

    const error = await expectHttpsError(handler(req(UID, { token: TOKEN })), 'failed-precondition');
    expect(error.details).toEqual({ reason: 'profile-missing' });
    expect((await db.collection('users').doc(UID).get()).exists).toBe(false);
  });

  it('registers the token and returns ok', async () => {
    await seedProfile();

    expect(await makeRegisterPushTokenHandler()(req(UID, { token: TOKEN }))).toEqual({
      status: 'ok',
    });
    expect(await storedTokens()).toEqual([TOKEN]);
  });

  it('maps an unexpected service failure to a STATIC internal', async () => {
    const handler = makeRegisterPushTokenHandler({
      write: () => Promise.reject(new Error(`boom ${TOKEN}`)),
    });

    const error = await expectHttpsError(handler(req(UID, { token: TOKEN })), 'internal');
    // The static message is the point: a raw rethrow would put the token — which
    // addresses a physical device — into the client-visible error.
    expect(error.message).toBe('The push token could not be registered.');
    expect(error.message).not.toContain(TOKEN);
  });

  it('never lets the token or the uid reach a log line', async () => {
    await seedProfile();
    const lines: unknown[] = [];
    const { logger } = await import('firebase-functions');
    const spy = logger.info;
    (logger as { info: unknown }).info = (...args: unknown[]) => {
      lines.push(args);
    };
    try {
      await makeRegisterPushTokenHandler()(req(UID, { token: TOKEN }));
    } finally {
      (logger as { info: unknown }).info = spy;
    }

    const serialized = JSON.stringify(lines);
    expect(serialized).not.toContain(TOKEN);
    expect(serialized).not.toContain(UID);
    expect(serialized).toContain('registered');
  });
});

describe('unregisterPushToken handler', () => {
  it('rejects unauthenticated callers', async () => {
    await expectHttpsError(
      makeUnregisterPushTokenHandler()(req(undefined, { token: TOKEN })),
      'unauthenticated',
    );
  });

  it('rejects a malformed request with invalid-argument', async () => {
    await expectHttpsError(
      makeUnregisterPushTokenHandler()(req(UID, { token: 42 })),
      'invalid-argument',
    );
  });

  it('maps an absent profile to failed-precondition', async () => {
    await expectHttpsError(
      makeUnregisterPushTokenHandler()(req(UID, { token: TOKEN })),
      'failed-precondition',
    );
  });

  it('removes the token and returns ok', async () => {
    await seedProfile();
    await makeRegisterPushTokenHandler()(req(UID, { token: TOKEN }));

    expect(await makeUnregisterPushTokenHandler()(req(UID, { token: TOKEN }))).toEqual({
      status: 'ok',
    });
    expect(await storedTokens()).toEqual([]);
  });

  it('maps an unexpected service failure to a STATIC internal', async () => {
    const handler = makeUnregisterPushTokenHandler({
      write: () => Promise.reject(new Error(`boom ${TOKEN}`)),
    });

    const error = await expectHttpsError(handler(req(UID, { token: TOKEN })), 'internal');
    expect(error.message).toBe('The push token could not be removed.');
    expect(error.message).not.toContain(TOKEN);
  });
});
