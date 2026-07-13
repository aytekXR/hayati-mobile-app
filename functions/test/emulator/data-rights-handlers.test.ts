// In-process tests of the M6.2 data-rights callable HANDLERS (ADR-019 D2/D5/D6):
// auth guard, confirm/validation, the typed-outcome → HttpsError mapping, and the
// token-window callable-surface commitments (updateNotificationPrivacy + exportData
// with an absent profile → typed failure, no write). Exercised against the
// firestore + auth emulators; the default admin app binds to demo-hayati.
import { getAuth } from 'firebase-admin/auth';
import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { CURRENT_LEGAL_VERSION } from '../../src/data-rights/data-rights-core';
import {
  makeDeleteAccountHandler,
  makeExportDataHandler,
  makeRecordConsentHandler,
  makeUpdateNotificationPrivacyHandler,
} from '../../src/data-rights/data-rights';
import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();
const auth = getAuth();

const UID = 'dr-uid';

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

async function seedProfile(uid: string): Promise<void> {
  await db.collection('users').doc(uid).set({
    status: 'married',
    contentLanguage: 'tr',
    register: 'respectful',
    createdAt: new Date(),
  });
}
async function putAuthUser(uid: string): Promise<void> {
  await auth.deleteUser(uid).catch(() => undefined);
  await auth.createUser({ uid });
}

beforeEach(async () => {
  await clearFirestoreData();
  await auth.deleteUser(UID).catch(() => undefined);
});

describe('deleteAccount handler', () => {
  it('rejects unauthenticated callers', async () => {
    await expectHttpsError(
      makeDeleteAccountHandler()(req(undefined, { confirm: 'DELETE' })),
      'unauthenticated',
    );
  });

  it('rejects a missing/wrong confirmation with invalid-argument', async () => {
    const handler = makeDeleteAccountHandler();
    const error = await expectHttpsError(handler(req(UID, {})), 'invalid-argument');
    expect(error.details).toEqual({ reason: 'bad-confirm' });
    await expectHttpsError(handler(req(UID, { confirm: 'delete' })), 'invalid-argument');
  });

  it('deletes an unpaired account end-to-end (Firestore + Auth)', async () => {
    await seedProfile(UID);
    await putAuthUser(UID);

    const result = await makeDeleteAccountHandler()(req(UID, { confirm: 'DELETE' }));
    expect(result).toEqual({ status: 'deleted' });
    expect((await db.collection('users').doc(UID).get()).exists).toBe(false);
    await expect(auth.getUser(UID)).rejects.toBeDefined();
  });

  it('maps an unexpected cascade failure to internal without leaking it', async () => {
    const handler = makeDeleteAccountHandler({
      cascade: async () => {
        throw new Error('cascade fell over');
      },
    });
    const error = await expectHttpsError(handler(req(UID, { confirm: 'DELETE' })), 'internal');
    expect(error.message).not.toContain('fell over');
  });
});

describe('exportData handler', () => {
  it('rejects unauthenticated callers', async () => {
    await expectHttpsError(makeExportDataHandler()(req(undefined, {})), 'unauthenticated');
  });

  it('maps an absent profile to failed-precondition (profile-missing), no write', async () => {
    const handler = makeExportDataHandler({ authLookup: async () => null });
    const error = await expectHttpsError(handler(req(UID, {})), 'failed-precondition');
    expect(error.details).toEqual({ reason: 'profile-missing' });
    expect((await db.collection('users').doc(UID).get()).exists).toBe(false);
  });

  it('returns a formatVersion-2 envelope for a live profile', async () => {
    await seedProfile(UID);
    const handler = makeExportDataHandler({
      authLookup: async () => ({ displayName: 'Aytek', email: 'a@x.com', photoURL: null }),
    });
    const doc = await handler(req(UID, {}));
    expect(doc.formatVersion).toBe(2);
    expect(doc.uid).toBe(UID);
    expect(doc.data.profile.displayName).toBe('Aytek');
  });
});

describe('updateNotificationPrivacy handler', () => {
  it('rejects unauthenticated and malformed requests', async () => {
    const handler = makeUpdateNotificationPrivacyHandler();
    await expectHttpsError(handler(req(undefined, { discreet: true })), 'unauthenticated');
    const error = await expectHttpsError(handler(req(UID, { discreet: 'yes' })), 'invalid-argument');
    expect(error.details).toEqual({ reason: 'bad-request' });
  });

  it('maps an absent profile to failed-precondition (profile-missing), no write', async () => {
    const handler = makeUpdateNotificationPrivacyHandler();
    const error = await expectHttpsError(handler(req(UID, { discreet: true })), 'failed-precondition');
    expect(error.details).toEqual({ reason: 'profile-missing' });
    expect((await db.collection('users').doc(UID).get()).exists).toBe(false);
  });

  it('sets discreet then clears it via the existing profile doc', async () => {
    await seedProfile(UID);
    const handler = makeUpdateNotificationPrivacyHandler();

    expect(await handler(req(UID, { discreet: true }))).toEqual({ status: 'ok' });
    expect((await db.collection('users').doc(UID).get()).get('notificationPrivacy')).toBe('discreet');

    expect(await handler(req(UID, { discreet: false }))).toEqual({ status: 'ok' });
    expect((await db.collection('users').doc(UID).get()).get('notificationPrivacy')).toBeUndefined();
  });
});

describe('recordConsent handler', () => {
  it('rejects unauthenticated and malformed requests', async () => {
    const handler = makeRecordConsentHandler();
    await expectHttpsError(handler(req(undefined, { withdraw: false })), 'unauthenticated');
    const error = await expectHttpsError(handler(req(UID, { withdraw: 'yes' })), 'invalid-argument');
    expect(error.details).toEqual({ reason: 'bad-request' });
  });

  it('maps an absent profile to failed-precondition (profile-missing), no write', async () => {
    const handler = makeRecordConsentHandler();
    const error = await expectHttpsError(handler(req(UID, { withdraw: false })), 'failed-precondition');
    expect(error.details).toEqual({ reason: 'profile-missing' });
    expect((await db.collection('users').doc(UID).get()).exists).toBe(false);
  });

  it('grants: server-stamps version + acceptedAt + ageAttested onto the users doc', async () => {
    await seedProfile(UID);
    const handler = makeRecordConsentHandler();

    expect(await handler(req(UID, { withdraw: false }))).toEqual({ status: 'ok' });

    const consent = (await db.collection('users').doc(UID).get()).get('consent') as {
      version: number;
      acceptedAt: Timestamp;
      ageAttested: boolean;
    };
    expect(consent.version).toBe(CURRENT_LEGAL_VERSION);
    expect(consent.ageAttested).toBe(true);
    // The client sends no timestamp: acceptedAt is a real server-stamped Timestamp.
    expect(consent.acceptedAt).toBeInstanceOf(Timestamp);
    expect(consent.acceptedAt.toMillis()).toBeGreaterThan(0);
  });

  it('withdraws: clears the consent field on the existing profile doc', async () => {
    await seedProfile(UID);
    const handler = makeRecordConsentHandler();

    await handler(req(UID, { withdraw: false }));
    expect((await db.collection('users').doc(UID).get()).get('consent')).toBeDefined();

    expect(await handler(req(UID, { withdraw: true }))).toEqual({ status: 'ok' });
    expect((await db.collection('users').doc(UID).get()).get('consent')).toBeUndefined();
  });

  it('a re-grant overwrites acceptedAt (and the stored version) — idempotent, latest-only', async () => {
    await seedProfile(UID);
    // Simulate a stale prior grant: an old acceptedAt and an old version.
    await db.collection('users').doc(UID).update({
      consent: { version: 0, acceptedAt: Timestamp.fromMillis(1000), ageAttested: true },
    });

    expect(await makeRecordConsentHandler()(req(UID, { withdraw: false }))).toEqual({ status: 'ok' });

    const consent = (await db.collection('users').doc(UID).get()).get('consent') as {
      version: number;
      acceptedAt: Timestamp;
      ageAttested: boolean;
    };
    expect(consent.version).toBe(CURRENT_LEGAL_VERSION);
    expect(consent.acceptedAt.toMillis()).toBeGreaterThan(1000);
    expect(consent.ageAttested).toBe(true);
  });
});
