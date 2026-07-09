import { getAuth } from 'firebase-admin/auth';
import { Firestore, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { type Request, onRequest } from 'firebase-functions/v2/https';
import type { Response } from 'express';

import { FUNCTIONS_REGION } from './create-invite';
import { normalizeInviteCode } from './invite-code';

/**
 * The invitee has no account when they follow the WhatsApp link, so this
 * endpoint is zero-auth BY DESIGN (architecture.md §3, resume-prompt M2.2):
 * no auth guard, no enforceAppCheck. The primary anti-enumeration defense is
 * the 31^8 ≈ 8.5e11 code space (invite-code.ts); the per-IP limiter below is a
 * cheap best-effort speed bump, not real rate-limit infrastructure.
 */

/** Best-effort per-IP fixed window: 30 requests / 60s. Documented decision. */
export const PREVIEW_RATE_LIMIT = 30;
export const PREVIEW_RATE_WINDOW_MS = 60_000;

export type InvitePreviewStatus = 'valid' | 'expired' | 'unknown';

/**
 * The ENTIRE surface the preview exposes. Designed to grow a `questionText`
 * field at M3; `invitePreviewResult` is the ONE place that builds it, so the
 * projection stays explicit and nothing (creatorUid, other invites) can leak.
 */
export interface InvitePreview {
  status: InvitePreviewStatus;
  creatorDisplayName?: string;
}

/**
 * Sole constructor of the response body: `creatorDisplayName` is included ONLY
 * when it is a non-empty string. Keeping the projection here means the leaked
 * surface is auditable in one spot.
 */
function invitePreviewResult(
  status: InvitePreviewStatus,
  creatorDisplayName?: string,
): InvitePreview {
  const result: InvitePreview = { status };
  if (typeof creatorDisplayName === 'string' && creatorDisplayName.length > 0) {
    result.creatorDisplayName = creatorDisplayName;
  }
  return result;
}

/** Resolves a creator's display name (injectable so the auth call is fakeable). */
export type CreatorNameLookup = (uid: string) => Promise<string | undefined>;

/**
 * Production lookup: the display name lives on the AUTH record, never in the
 * invite doc, so the invite projection can't leak more than a name. Any failure
 * (no such user, auth unavailable) rejects and is swallowed by `previewInvite`.
 */
const authCreatorName: CreatorNameLookup = (uid) =>
  getAuth()
    .getUser(uid)
    .then((user) => user.displayName);

/**
 * READ-ONLY preview lookup for `code` (already normalized to the valid format).
 * Never writes — the zero-auth path must not amplify writes, and createInvite
 * already owns lazy expiry. `lookupName` is injectable like invite-service's
 * `generateCode`.
 */
export async function previewInvite(
  db: Firestore,
  code: string,
  lookupName: CreatorNameLookup = authCreatorName,
): Promise<InvitePreview> {
  const snapshot = await db.collection('invites').doc(code).get();
  if (!snapshot.exists) {
    return invitePreviewResult('unknown');
  }

  const data = snapshot.data()!;
  const expiresAt = data.expiresAt;
  const isValid =
    data.status === 'pending' &&
    expiresAt instanceof Timestamp &&
    expiresAt.toMillis() > Date.now();
  if (!isValid) {
    // status === 'expired', past expiresAt, or a malformed doc — all uniform
    // 'expired'. Never mark lazy expiry here (createInvite owns that write).
    return invitePreviewResult('expired');
  }

  let creatorDisplayName: string | undefined;
  try {
    creatorDisplayName = await lookupName(data.creatorUid as string);
  } catch (error) {
    // A missing name never downgrades a valid invite.
    logger.warn('invitePreview creator lookup failed', {
      codePrefix: code.slice(0, 3),
      error,
    });
  }
  return invitePreviewResult('valid', creatorDisplayName);
}

/** Allow-or-reject one request for `key` under the fixed window. */
export interface RateLimiter {
  take(key: string): boolean;
}

/**
 * In-memory fixed-window limiter. Best-effort and per-instance (a scaled-out
 * deployment gets one bucket per container) — documented as a speed bump, not
 * a guarantee. `now` is injectable so in-process tests drive time. Fully
 * elapsed windows are pruned lazily on every call so the Map can't grow
 * unbounded.
 */
export function createRateLimiter(
  limit: number = PREVIEW_RATE_LIMIT,
  windowMs: number = PREVIEW_RATE_WINDOW_MS,
  now: () => number = Date.now,
): RateLimiter {
  const windows = new Map<string, { start: number; count: number }>();
  return {
    take(key: string): boolean {
      const t = now();
      for (const [k, w] of windows) {
        if (t - w.start >= windowMs) {
          windows.delete(k);
        }
      }
      const current = windows.get(key);
      if (current === undefined) {
        windows.set(key, { start: t, count: 1 });
        return true;
      }
      if (current.count >= limit) {
        return false;
      }
      current.count += 1;
      return true;
    },
  };
}

export interface InvitePreviewHandlerDeps {
  /** Preview service seam (defaults to the Firestore-backed `previewInvite`). */
  preview?: typeof previewInvite;
  /** Rate limiter seam (defaults to a fresh per-instance limiter). */
  limiter?: RateLimiter;
  /** Clock seam threaded into the default limiter. */
  now?: () => number;
}

/**
 * Handler factory mirroring `makeCreateInviteHandler`: every I/O dependency is
 * an injectable seam so the error, rate-limit, and auth-lookup paths are
 * exercisable without the functions emulator.
 */
export function makeInvitePreviewHandler(deps: InvitePreviewHandlerDeps = {}) {
  const now = deps.now ?? Date.now;
  const preview = deps.preview ?? previewInvite;
  const limiter =
    deps.limiter ??
    createRateLimiter(PREVIEW_RATE_LIMIT, PREVIEW_RATE_WINDOW_MS, now);

  return async (req: Request, res: Response): Promise<void> => {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'method-not-allowed' });
      return;
    }

    // Rate-limit BEFORE any Firestore read — a rejected caller costs nothing.
    const ip = req.ip ?? 'unknown';
    if (!limiter.take(ip)) {
      res.status(429).json({ error: 'rate-limited' });
      return;
    }

    const rawCode = req.query.code;
    if (typeof rawCode !== 'string') {
      // Absent param (or ?code=x&code=y → array): the REQUEST is malformed,
      // distinct from a well-formed request for an unknown code.
      res.status(400).json({ error: 'missing-code' });
      return;
    }

    // Log a PREFIX only: pairing the full code with its validity would turn the
    // logs into a code oracle. Validity is never logged here.
    logger.info('invitePreview', {
      codePrefix: rawCode.slice(0, 3),
      ip,
    });

    const code = normalizeInviteCode(rawCode);
    if (code === null) {
      // Malformed but present: a bad code can never match a real doc, so
      // short-circuit to the uniform 'unknown' WITHOUT touching Firestore.
      res.status(200).json(invitePreviewResult('unknown'));
      return;
    }

    try {
      res.status(200).json(await preview(getFirestore(), code));
    } catch (error) {
      // Never leak internal messages to the zero-auth caller.
      logger.error('invitePreview failed', error);
      res.status(500).json({ error: 'internal' });
    }
  };
}

export const invitePreview = onRequest(
  {
    region: FUNCTIONS_REGION,
    // Zero-auth by design: no enforceAppCheck (the invitee has no account),
    // and no CORS option (native-only consumer; web preview is a later
    // milestone).
  },
  makeInvitePreviewHandler(),
);
