// In-process tests of the preview HANDLER (method/param/rate-limit/error
// mapping) and the preview SERVICE (previewInvite against the firestore
// emulator). The full HTTP wire contract is covered end-to-end through the
// functions emulator in invite-preview.test.ts. Fabricated req/res mirror the
// way create-invite-handler.test.ts fabricates a CallableRequest.
import { getAuth } from 'firebase-admin/auth';
import { Timestamp } from 'firebase-admin/firestore';
import type { Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  PREVIEW_RATE_LIMIT,
  PREVIEW_RATE_WINDOW_MS,
  makeInvitePreviewHandler,
  previewInvite,
} from '../../src/invites/invite-preview';
import { adminFirestore, clearFirestoreData } from '../support/admin';

// Binds the default admin app to the emulator before any getFirestore() /
// previewInvite() resolves it.
const db = adminFirestore();
const invites = db.collection('invites');

const VALID_CODE = 'ABCDEFGH';

function seedInvite(
  code: string,
  data: Record<string, unknown>,
): Promise<FirebaseFirestore.WriteResult> {
  return invites.doc(code).set({ createdAt: Timestamp.now(), ...data });
}

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

function fakeReq(overrides: Partial<Request> = {}): Request {
  return {
    method: 'GET',
    query: {},
    ip: '203.0.113.7',
    ...overrides,
  } as unknown as Request;
}

/** Runs the handler against a fabricated GET and returns the captured res. */
async function invoke(
  handler: ReturnType<typeof makeInvitePreviewHandler>,
  req: Request,
): Promise<CapturedRes> {
  const res = fakeRes();
  await handler(req, res as unknown as Response);
  return res;
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('invitePreview handler', () => {
  it('rejects non-GET methods with 405', async () => {
    const handler = makeInvitePreviewHandler({
      preview: async () => ({ status: 'valid' }),
    });
    const res = await invoke(handler, fakeReq({ method: 'POST' }));
    expect(res.statusCode).toBe(405);
    expect(res.body).toEqual({ error: 'method-not-allowed' });
  });

  it('returns 400 when the code param is absent', async () => {
    const handler = makeInvitePreviewHandler({
      preview: async () => ({ status: 'valid' }),
    });
    const res = await invoke(handler, fakeReq({ query: {} }));
    expect(res.statusCode).toBe(400);
    expect(res.body).toEqual({ error: 'missing-code' });
  });

  it('returns 400 when the code param is repeated (array, not a single string)', async () => {
    const handler = makeInvitePreviewHandler({
      preview: async () => ({ status: 'valid' }),
    });
    const res = await invoke(
      handler,
      fakeReq({ query: { code: ['A', 'B'] } as unknown as Request['query'] }),
    );
    expect(res.statusCode).toBe(400);
    expect(res.body).toEqual({ error: 'missing-code' });
  });

  it('short-circuits a malformed code to 200 unknown WITHOUT calling the service', async () => {
    let called = false;
    const handler = makeInvitePreviewHandler({
      preview: async () => {
        called = true;
        return { status: 'valid' };
      },
    });
    const res = await invoke(handler, fakeReq({ query: { code: 'not-a-code' } }));
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ status: 'unknown' });
    expect(called).toBe(false);
  });

  it('maps a service failure to 500 internal without leaking the message', async () => {
    const handler = makeInvitePreviewHandler({
      preview: async () => {
        throw new Error('firestore fell over');
      },
    });
    const res = await invoke(handler, fakeReq({ query: { code: VALID_CODE } }));
    expect(res.statusCode).toBe(500);
    expect(res.body).toEqual({ error: 'internal' });
    expect(JSON.stringify(res.body)).not.toContain('fell over');
  });

  it('enforces the per-IP fixed window: Nth ok, N+1 rejected, resets next window', async () => {
    let clock = 1_000_000;
    const handler = makeInvitePreviewHandler({
      preview: async () => ({ status: 'valid' }),
      now: () => clock,
    });

    for (let i = 0; i < PREVIEW_RATE_LIMIT; i += 1) {
      const res = await invoke(handler, fakeReq({ query: { code: VALID_CODE } }));
      expect(res.statusCode).toBe(200);
    }

    const over = await invoke(handler, fakeReq({ query: { code: VALID_CODE } }));
    expect(over.statusCode).toBe(429);
    expect(over.body).toEqual({ error: 'rate-limited' });

    // A different IP has its own bucket, unaffected by the exhausted one.
    const otherIp = await invoke(
      handler,
      fakeReq({ ip: '198.51.100.9', query: { code: VALID_CODE } }),
    );
    expect(otherIp.statusCode).toBe(200);

    // Advancing past the window frees the original IP again.
    clock += PREVIEW_RATE_WINDOW_MS;
    const afterReset = await invoke(
      handler,
      fakeReq({ query: { code: VALID_CODE } }),
    );
    expect(afterReset.statusCode).toBe(200);
  });

  it("falls back to 'unknown' IP when req.ip is undefined", async () => {
    const handler = makeInvitePreviewHandler({
      preview: async () => ({ status: 'valid' }),
    });
    const res = await invoke(
      handler,
      fakeReq({ ip: undefined, query: { code: VALID_CODE } }),
    );
    expect(res.statusCode).toBe(200);
  });
});

describe('previewInvite service', () => {
  it("returns 'unknown' for an absent code", async () => {
    expect(await previewInvite(db, 'ABSENT23')).toEqual({ status: 'unknown' });
  });

  it("returns 'valid' with the creator name when the lookup succeeds", async () => {
    await seedInvite(VALID_CODE, {
      creatorUid: 'creator-1',
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });
    const preview = await previewInvite(db, VALID_CODE, async () => 'Layla');
    expect(preview).toEqual({ status: 'valid', creatorDisplayName: 'Layla' });
  });

  it("resolves the creator name from the auth record via the default lookup", async () => {
    const uid = 'creator-default-lookup';
    await getAuth()
      .deleteUser(uid)
      .catch(() => undefined);
    await getAuth().createUser({ uid, displayName: 'Noor' });
    await seedInvite(VALID_CODE, {
      creatorUid: uid,
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });
    // No injected lookup: exercises the production authCreatorName path.
    expect(await previewInvite(db, VALID_CODE)).toEqual({
      status: 'valid',
      creatorDisplayName: 'Noor',
    });
  });

  it("returns 'valid' without a name when the auth lookup throws", async () => {
    await seedInvite(VALID_CODE, {
      creatorUid: 'creator-1',
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });
    const preview = await previewInvite(db, VALID_CODE, async () => {
      throw new Error('no such user');
    });
    expect(preview).toEqual({ status: 'valid' });
  });

  it("returns 'valid' without a name when the display name is empty", async () => {
    await seedInvite(VALID_CODE, {
      creatorUid: 'creator-1',
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });
    const preview = await previewInvite(db, VALID_CODE, async () => '');
    expect(preview).toEqual({ status: 'valid' });
  });

  it("returns 'expired' for a doc already marked expired", async () => {
    await seedInvite(VALID_CODE, {
      creatorUid: 'creator-1',
      status: 'expired',
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });
    expect(await previewInvite(db, VALID_CODE, async () => 'Layla')).toEqual({
      status: 'expired',
    });
  });

  it("returns 'expired' for a pending doc past its expiry", async () => {
    await seedInvite(VALID_CODE, {
      creatorUid: 'creator-1',
      status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() - 1),
    });
    expect(await previewInvite(db, VALID_CODE, async () => 'Layla')).toEqual({
      status: 'expired',
    });
  });

  it("treats a pending doc with no expiresAt as 'expired' (defensive)", async () => {
    await seedInvite(VALID_CODE, {
      creatorUid: 'creator-1',
      status: 'pending',
    });
    expect(await previewInvite(db, VALID_CODE)).toEqual({ status: 'expired' });
  });
});
