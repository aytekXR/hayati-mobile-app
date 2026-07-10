// In-process tests of the callable HANDLER (auth guard, wire validation, and
// the domain-error → HttpsError mapping), exercised against the firestore
// emulator. The full HTTP protocol — token verification, wire envelope, error
// status codes — is covered end-to-end through the functions emulator in
// join-invite-callable.test.ts. Fabricated CallableRequests mirror
// create-invite-handler.test.ts.
import { HttpsError } from 'firebase-functions/v2/https';
import type { CallableRequest } from 'firebase-functions/v2/https';
import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { makeJoinInviteHandler } from '../../src/invites/join-invite';
import {
  AlreadyPairedError,
  ConsumedInviteError,
  ExpiredInviteError,
  JoinInviteError,
  JoinResult,
  ProfileMissingError,
  SelfJoinError,
  UnknownInviteError,
  joinInvite,
} from '../../src/invites/join-service';
import { adminFirestore, clearFirestoreData } from '../support/admin';

// Binds the default admin app to the emulator before the handler's
// getFirestore() call resolves it.
const db = adminFirestore();

function request(
  auth: { uid: string } | undefined,
  data: unknown = {},
): CallableRequest {
  return { auth, data } as unknown as CallableRequest;
}

/**
 * Asserts `run` rejects with an HttpsError of `code` and, when given, the
 * `details.reason` the FROZEN M2.3 contract requires.
 */
async function expectHttpsError(
  run: Promise<unknown>,
  code: string,
  reason?: string,
): Promise<void> {
  const error = await run.then(
    () => {
      throw new Error(`expected HttpsError '${code}' but the call succeeded`);
    },
    (thrown) => thrown as unknown,
  );
  expect(error).toBeInstanceOf(HttpsError);
  expect((error as HttpsError).code).toBe(code);
  if (reason !== undefined) {
    expect((error as HttpsError).details).toEqual({ reason });
  }
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('joinInvite handler — guards', () => {
  it('rejects an unauthenticated caller', async () => {
    const handler = makeJoinInviteHandler();
    await expectHttpsError(
      handler(request(undefined, { code: 'AAAA2222' })),
      'unauthenticated',
    );
  });

  it('rejects a present-but-empty uid', async () => {
    const handler = makeJoinInviteHandler();
    await expectHttpsError(
      handler(request({ uid: '' }, { code: 'AAAA2222' })),
      'unauthenticated',
    );
  });

  it('rejects a non-string code with invalid-argument', async () => {
    const handler = makeJoinInviteHandler();
    await expectHttpsError(
      handler(request({ uid: 'joiner' }, { code: 12345678 })),
      'invalid-argument',
    );
  });

  it('rejects a missing code with invalid-argument', async () => {
    const handler = makeJoinInviteHandler();
    await expectHttpsError(
      handler(request({ uid: 'joiner' }, {})),
      'invalid-argument',
    );
  });
});

describe('joinInvite handler — domain-error mapping', () => {
  // The reason on each domain error is the ONLY input to the mapping, so a
  // fake join throwing each error proves the full table without seeding
  // Firestore state per case.
  const cases: Array<[JoinInviteError, string, string]> = [
    [new UnknownInviteError(), 'not-found', 'unknown'],
    [new ExpiredInviteError(), 'failed-precondition', 'expired'],
    [new ConsumedInviteError(), 'failed-precondition', 'consumed'],
    [new SelfJoinError(), 'failed-precondition', 'self-join'],
    [new AlreadyPairedError(), 'failed-precondition', 'already-paired'],
    [new ProfileMissingError(), 'failed-precondition', 'profile-missing'],
  ];

  it.each(cases)('maps %o to its HttpsError code + reason', async (error, code, reason) => {
    const handler = makeJoinInviteHandler(async () => {
      throw error;
    });
    await expectHttpsError(
      handler(request({ uid: 'joiner' }, { code: 'AAAA2222' })),
      code,
      reason,
    );
  });

  it('maps an unexpected failure to internal without leaking it', async () => {
    const handler = makeJoinInviteHandler(async () => {
      throw new Error('firestore fell over');
    });
    const error = await handler(
      request({ uid: 'joiner' }, { code: 'AAAA2222' }),
    ).then(
      () => {
        throw new Error('expected the handler to reject');
      },
      (thrown) => thrown as HttpsError,
    );
    expect(error.code).toBe('internal');
    expect(error.message).not.toContain('fell over');
  });
});

describe('joinInvite handler — happy path (real service)', () => {
  it('pairs the caller and returns the coupleId', async () => {
    const profile = {
      status: 'married',
      contentLanguage: 'tr',
      register: 'respectful',
      createdAt: Timestamp.now(),
    };
    await db.collection('users').doc('creator').set(profile);
    await db.collection('users').doc('joiner').set(profile);
    await db.collection('invites').doc('AAAA2222').set({
      creatorUid: 'creator',
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
      createdAt: Timestamp.now(),
    });

    // No injected join: exercises the real joinInvite service through the
    // handler, including the optional timezone plumbing.
    const handler = makeJoinInviteHandler(joinInvite);
    const result: JoinResult = await handler(
      request({ uid: 'joiner' }, { code: 'AAAA2222', timezone: 'Asia/Riyadh' }),
    );

    const couple = (
      await db.collection('couples').doc(result.coupleId).get()
    ).data()!;
    expect(couple.memberUids).toEqual(['creator', 'joiner']);
    expect(couple.timezone).toBe('Asia/Riyadh');
  });
});
