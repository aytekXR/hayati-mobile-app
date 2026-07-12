// In-process tests of the callable HANDLER (auth guard + error mapping),
// exercised against the firestore emulator. The full HTTP protocol — token
// verification, wire shapes — is covered end-to-end through the functions
// emulator in create-invite-callable.test.ts.
import { HttpsError } from 'firebase-functions/v2/https';
import type { CallableRequest } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  makeCreateInviteHandler,
} from '../../src/invites/create-invite';
import {
  CreatorAlreadyPairedError,
  InviteCodeSpaceExhaustedError,
} from '../../src/invites/invite-service';
import { adminFirestore, clearFirestoreData } from '../support/admin';

// Binds the default admin app to the emulator before the handler's
// getFirestore() call resolves it.
const db = adminFirestore();

/** Since ADR-019, issuing requires the creator's profile to exist. */
function seedProfile(uid: string): Promise<unknown> {
  return db.collection('users').doc(uid).set({
    status: 'married',
    contentLanguage: 'tr',
    register: 'respectful',
    createdAt: new Date(),
  });
}

function authedRequest(uid: string): CallableRequest {
  return { auth: { uid } } as unknown as CallableRequest;
}

async function expectHttpsError(
  run: Promise<unknown>,
  code: string,
): Promise<void> {
  const error = await run.then(
    () => {
      throw new Error(`expected HttpsError '${code}' but the call succeeded`);
    },
    (thrown) => thrown as unknown,
  );
  expect(error).toBeInstanceOf(HttpsError);
  expect((error as HttpsError).code).toBe(code);
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('createInvite handler', () => {
  it('rejects unauthenticated callers', async () => {
    const handler = makeCreateInviteHandler();
    await expectHttpsError(
      handler({ auth: undefined } as unknown as CallableRequest),
      'unauthenticated',
    );
  });

  it('issues an invite for the caller and persists it', async () => {
    await seedProfile('handler-uid');
    const handler = makeCreateInviteHandler();
    const issued = await handler(authedRequest('handler-uid'));

    const doc = await db.collection('invites').doc(issued.code).get();
    expect(doc.exists).toBe(true);
    expect(doc.data()!.creatorUid).toBe('handler-uid');
    expect(issued.reused).toBe(false);
  });

  it("maps an absent creator profile to failed-precondition / 'profile-missing' (ADR-019 INVITE-1)", async () => {
    // Real issue, no profile seeded: the token-window closure on the admin-SDK
    // callable surface. Positive control (a live profile issues) is above.
    const handler = makeCreateInviteHandler();
    const error = await handler(authedRequest('no-profile-uid')).then(
      () => {
        throw new Error('expected the handler to reject');
      },
      (thrown) => thrown as HttpsError,
    );
    expect(error.code).toBe('failed-precondition');
    expect(error.details).toEqual({ reason: 'profile-missing' });
  });

  it('maps code-space exhaustion to resource-exhausted', async () => {
    const handler = makeCreateInviteHandler(async () => {
      throw new InviteCodeSpaceExhaustedError();
    });
    await expectHttpsError(
      handler(authedRequest('handler-uid')),
      'resource-exhausted',
    );
  });

  it("maps an already-paired creator to failed-precondition / 'already-paired'", async () => {
    const handler = makeCreateInviteHandler(async () => {
      throw new CreatorAlreadyPairedError();
    });
    const error = await handler(authedRequest('handler-uid')).then(
      () => {
        throw new Error('expected the handler to reject');
      },
      (thrown) => thrown as HttpsError,
    );
    expect(error.code).toBe('failed-precondition');
    expect(error.details).toEqual({ reason: 'already-paired' });
  });

  it('maps unexpected failures to internal without leaking them', async () => {
    const handler = makeCreateInviteHandler(async () => {
      throw new Error('firestore fell over');
    });
    const error = await handler(authedRequest('handler-uid')).then(
      () => {
        throw new Error('expected the handler to reject');
      },
      (thrown) => thrown as HttpsError,
    );
    expect(error.code).toBe('internal');
    expect(error.message).not.toContain('fell over');
  });
});
