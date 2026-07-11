// The HTTP shell for the RevenueCat webhook (M4.1, ADR-013): auth + body-shape
// gating, then hand a parsed event to the service. The repo's FIRST env/secret
// seam — the shared token is read from process.env.RC_WEBHOOK_TOKEN at REQUEST
// time (never a module-load capture), which covers every runtime uniformly: at
// deploy `secrets: ['RC_WEBHOOK_TOKEN']` binds Cloud Secret Manager into the
// process env, the emulator loads `.env.demo-hayati`, and tests inject a literal
// through the seam. Handler factory with defaulted DI (the invitePreview mold).
import { timingSafeEqual } from 'node:crypto';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { type Request, onRequest } from 'firebase-functions/v2/https';
import type { Response } from 'express';

import { FUNCTIONS_REGION } from '../invites/create-invite';
import { logProjection, parseRcEvent } from './entitlement-core';
import { ProcessOutcome, processRevenueCatEvent } from './entitlement-service';

export interface RevenueCatWebhookDeps {
  /**
   * Resolves the expected `Authorization` token. Default reads
   * process.env.RC_WEBHOOK_TOKEN AT REQUEST TIME (a fresh read per request) so a
   * late-bound secret is picked up without a redeploy; tests inject a literal.
   */
  expectedToken?: () => string | undefined;
  /** Service seam (defaults to the Firestore-backed processRevenueCatEvent). */
  process?: typeof processRevenueCatEvent;
  /** Firestore handle seam — the shell resolves it and passes it to the service. */
  db?: () => Firestore;
  /** Clock threaded into the service (lane updatedAtMs). */
  now?: () => number;
}

/**
 * Constant-time token compare. `timingSafeEqual` throws on unequal-length
 * buffers, so the length check comes first (it leaks only the length — standard
 * and acceptable; the token's secrecy is the anti-forgery boundary, ADR-013). A
 * missing/non-string header is an immediate reject.
 */
function tokenMatches(provided: string | undefined, expected: string): boolean {
  if (typeof provided !== 'string') {
    return false;
  }
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) {
    return false;
  }
  return timingSafeEqual(a, b);
}

/** The ONE success-body constructor: 200 for applied AND every decided skip. */
function webhookResult(outcome: ProcessOutcome): { status: 'processed' | 'skipped'; decision: string } {
  return {
    status: outcome.decision === 'applied' ? 'processed' : 'skipped',
    decision: outcome.decision,
  };
}

/**
 * Handler factory (invitePreview mold): every I/O dependency is a defaulted
 * injectable seam so the auth/validation/error paths are exercisable without the
 * emulator. Validation order is fixed (ADR-013 Decision 1/2):
 *   405 non-POST → 503 unconfigured (fail-closed) → 401 bad/missing token →
 *   400 malformed envelope → service call → 500 systemic (logged, never leaked).
 * There is deliberately NO rate limiter: a 429 to RC is a non-200 that burns its
 * 5-retry budget on legitimate events (the 401 path is the cheap gate).
 */
export function makeRevenueCatWebhookHandler(deps: RevenueCatWebhookDeps = {}) {
  const expectedToken = deps.expectedToken ?? (() => process.env.RC_WEBHOOK_TOKEN);
  const processEvent = deps.process ?? processRevenueCatEvent;
  const resolveDb = deps.db ?? getFirestore;
  const now = deps.now;

  return async (req: Request, res: Response): Promise<void> => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method-not-allowed' });
      return;
    }

    // Fail closed BEFORE the auth compare: an absent/empty secret must never mean
    // "accept everything". 503 self-heals within RC's retry budget once the
    // secret is bound; it is checked ahead of the token compare so a
    // misconfiguration can never be mistaken for an unauthorized caller.
    const expected = expectedToken();
    if (expected === undefined || expected.length === 0) {
      logger.error('revenuecat_webhook: unconfigured (RC_WEBHOOK_TOKEN absent)');
      res.status(503).json({ error: 'unconfigured' });
      return;
    }

    // RC sends the dashboard token VERBATIM in Authorization (no Bearer, no HMAC).
    if (!tokenMatches(req.get('authorization'), expected)) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }

    // Syntactically invalid JSON never reaches here (the framework body parser
    // answers its own 400). A valid-JSON body that is not structurally an RC
    // webhook is an EXPLICIT 400 — never a fall-through to a thrown 500.
    const parsed = parseRcEvent(req.body);
    if (parsed.status === 'malformed') {
      logger.warn('revenuecat_webhook: malformed body', { decision: 'malformed' });
      res.status(400).json({ error: 'malformed' });
      return;
    }

    try {
      const outcome = await processEvent(resolveDb(), parsed.event, { now });
      res.status(200).json(webhookResult(outcome));
    } catch (error) {
      // Systemic only (Firestore unavailable): a 500 is DESIRED here — RC's retry
      // is the recovery path. Log through the PII-safe projection; never leak.
      logger.error('revenuecat_webhook: internal failure', {
        ...logProjection(parsed.event, 'internal'),
        error: error instanceof Error ? error.message : String(error),
      });
      res.status(500).json({ error: 'internal' });
    }
  };
}

export const revenueCatWebhook = onRequest(
  {
    region: FUNCTIONS_REGION,
    // The shared token binds from Cloud Secret Manager at deploy (deploy-verified
    // at the first Blaze deploy, same posture as the rollover schedule trigger).
    // The emulator tolerates this declared-but-absent secret (it warns; the
    // e2e token arrives via functions/.env.demo-hayati). If a future
    // firebase-tools regresses on the declared-but-absent secret at emulator
    // boot, drop this option — the request-time env read is what actually feeds
    // the token, so nothing else changes.
    secrets: ['RC_WEBHOOK_TOKEN'],
    // No enforceAppCheck (server-to-server), no CORS (no browser consumer), and
    // deliberately NO rate limiter (ADR-013 Decision 1).
  },
  makeRevenueCatWebhookHandler(),
);
