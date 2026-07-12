// The onCall shell for the M5.1 coach (ADR-016 Decisions 1/2/8) — the safety
// spine. A factory with defaulted DI (the makeRevenueCatWebhookHandler mold) so
// tests inject db/now/provider/caps/rateLimiter (+ a detector seam for the
// forced-throw sentinel case). This handler DEVIATES from the invite molds on
// purpose (Decision 8): NO uid-bearing entry log, NO raw-object catch log — the
// WHOLE body is wrapped so no non-HttpsError can escape (which the callable
// framework would auto-log with message + stack), every throw becomes a
// static-message HttpsError, and every log line goes through logCoachEvent (typed
// fields only — no text, no uid; crisis lines drop coupleId too).
//
// The pipeline order is FIXED and fail-closed (Decision 2): auth → per-uid rate
// limit → crisis pre-scan (BEFORE any validation/gating — a person in crisis is
// never turned away by a paywall, a cap, or an invalid-argument) → validation →
// transactional reserve (membership → premium → caps) → provider call (outside the
// txn, refund-on-failure) → crisis post-filter → reply.
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';

import { FUNCTIONS_REGION } from '../invites/create-invite';
import { RateLimiter, createRateLimiter } from '../invites/invite-preview';
import {
  CapConfig,
  CoachEventInput,
  DEFAULT_CAPS,
  logCoachEvent,
  truncateForScan,
  validateCoachRequest,
} from './coach-core';
import { CrisisCategory } from './crisis-lexicon';
import { CrisisVerdict, detectCrisis } from './crisis';
import { helpResponse } from './help-content';
import {
  CoachLanguage,
  CoachProvider,
  ProviderUnavailableError,
  UnconfiguredCoachProvider,
} from './provider-port';
import { refundCoachTurn, reserveCoachTurn } from './coach-service';

/** Per-uid in-memory rate limit (Decision 2): 30 calls/min, the invitePreview mold. */
export const COACH_RATE_LIMIT = 30;
export const COACH_RATE_WINDOW_MS = 60_000;

/** The M5.2-frozen response contract (Decision 1). `remaining` only on capped paths. */
export interface CoachResponse {
  kind: 'reply' | 'help';
  category?: CrisisCategory;
  text: string;
  remaining?: { daily: number; monthly: number };
}

export interface CoachProxyDeps {
  /** Firestore handle seam (default: lazy getFirestore, resolved only when reserving). */
  db?: () => import('firebase-admin/firestore').Firestore;
  /** Injectable clock (default Date.now) — threaded into reserve + the limiter + latency. */
  now?: () => number;
  /** The provider port (default: the fail-closed UnconfiguredCoachProvider — deploy-safe). */
  provider?: CoachProvider;
  /** Cap config (default DEFAULT_CAPS). */
  caps?: CapConfig;
  /** Per-uid limiter (default: a fresh per-instance limiter on `now`). Resettable for tests. */
  rateLimiter?: RateLimiter;
  /** Crisis detector seam (default detectCrisis) — a throwing detector pins the fail-closed catch. */
  detectCrisis?: (texts: readonly string[]) => CrisisVerdict;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Defensively extract candidate scan texts from the RAW, untrusted body (Decision
 * 2): the crisis pre-scan runs BEFORE validation, so a malformed body must yield
 * zero texts (and fall through) rather than throw. Every message's `text` is
 * scanned regardless of role — a forged `assistant` turn is still attacker input.
 */
function extractCandidateTexts(data: unknown): string[] {
  if (!isRecord(data) || !Array.isArray(data.messages)) {
    return [];
  }
  const texts: string[] = [];
  for (const message of data.messages) {
    if (isRecord(message) && typeof message.text === 'string') {
      texts.push(message.text);
    }
  }
  return texts;
}

/** The client-declared language, untouched (help-copy localization only, never detection). */
function extractLanguage(data: unknown): unknown {
  return isRecord(data) ? data.language : undefined;
}

/** Narrow an untrusted language to a CoachLanguage for the log line (EN on junk). */
function toCoachLanguage(value: unknown): CoachLanguage {
  return value === 'tr' || value === 'ar' || value === 'en' ? value : 'en';
}

/**
 * Builds the coach proxy handler (Decision 1/2/8). Every I/O dependency is a
 * defaulted seam. The provider default is the fail-closed UnconfiguredCoachProvider
 * — so this callable DEPLOYS safely (honest `unavailable`) before any provider is
 * chosen.
 */
export function makeCoachProxyHandler(deps: CoachProxyDeps = {}) {
  const now = deps.now ?? Date.now;
  const resolveDb = deps.db ?? getFirestore;
  const provider = deps.provider ?? new UnconfiguredCoachProvider();
  const caps = deps.caps ?? DEFAULT_CAPS;
  const limiter = deps.rateLimiter ?? createRateLimiter(COACH_RATE_LIMIT, COACH_RATE_WINDOW_MS, now);
  const detect = deps.detectCrisis ?? detectCrisis;

  return async (request: CallableRequest): Promise<CoachResponse> => {
    const startedAt = now();
    /** One log line per outcome — typed fields only (no text, no uid; Decision 8). */
    const emit = (input: CoachEventInput): void => {
      logger.info('coachProxy', logCoachEvent({ ...input, latencyMs: now() - startedAt }));
    };

    try {
      // (1) Auth — guard the uid itself (the emulator's debug mode passes garbage
      // tokens through as auth with an undefined uid), like both existing callables.
      const uid = request.auth?.uid;
      if (uid === undefined || uid.length === 0) {
        throw new HttpsError('unauthenticated', 'coachProxy requires a signed-in caller.');
      }

      // (2) Per-uid rate limit — bounds the only path that consumes no cap (the scan).
      if (!limiter.take(uid)) {
        emit({ outcome: 'rate-limited', language: toCoachLanguage(extractLanguage(request.data)) });
        throw new HttpsError('resource-exhausted', 'Too many coach requests; please slow down.', {
          reason: 'rate-limited',
        });
      }

      // (3) Crisis pre-scan — BEFORE any validation/rejection. Runs for ANY caller
      // (premium or not, member or not): no reads, no cap, no provider. A detector
      // throw is fail-closed to the help path (safety doubt never routes to persona).
      const rawLanguage = extractLanguage(request.data);
      const scanTexts = extractCandidateTexts(request.data).map(truncateForScan);
      let preVerdict: CrisisVerdict;
      try {
        preVerdict = detect(scanTexts);
      } catch {
        emit({ outcome: 'help-path', language: toCoachLanguage(rawLanguage) });
        return { kind: 'help', text: helpResponse(rawLanguage) };
      }
      if (preVerdict.hit) {
        emit({ outcome: 'crisis', language: toCoachLanguage(rawLanguage) });
        return { kind: 'help', category: preVerdict.category, text: helpResponse(rawLanguage) };
      }

      // (4) Input validation (bounds + enums).
      const validation = validateCoachRequest(request.data);
      if (!validation.ok) {
        emit({ outcome: 'invalid', language: toCoachLanguage(rawLanguage) });
        throw new HttpsError('invalid-argument', 'coachProxy request is malformed.');
      }
      const coachRequest = validation.request;

      // (5) Transactional reserve: membership → premium → caps (one read set).
      const db = resolveDb();
      const reserve = await reserveCoachTurn(db, {
        coupleId: coachRequest.coupleId,
        uid,
        nowMs: now(),
        caps,
      });
      const logBase = {
        language: coachRequest.language,
        coupleId: coachRequest.coupleId,
        personaId: coachRequest.personaId,
      } as const;
      if (reserve.kind === 'not-member') {
        emit({ outcome: 'not-member', ...logBase });
        throw new HttpsError('permission-denied', 'You are not a member of this couple.');
      }
      if (reserve.kind === 'not-premium') {
        emit({ outcome: 'not-premium', ...logBase });
        throw new HttpsError('failed-precondition', 'The coach is a premium feature.', {
          reason: 'not-premium',
        });
      }
      if (reserve.kind === 'cap-exceeded') {
        emit({ outcome: reserve.which, ...logBase });
        throw new HttpsError('resource-exhausted', 'You have reached your coach message limit.', {
          reason: reserve.which,
        });
      }
      if (reserve.kind === 'internal') {
        emit({ outcome: 'internal', ...logBase });
        throw new HttpsError('internal', 'The coach is temporarily unavailable.');
      }
      const { remaining, reservedDayKey, reservedMonthKey } = reserve;

      // (6) Provider call — OUTSIDE the transaction, after the reserve. ANY throw is
      // an infra/outage signal (not a crisis): refund best-effort, log the
      // classification enum ONLY (never the error message), map to `unavailable`.
      let reply: { text: string };
      try {
        reply = await provider.generateReply({
          personaId: coachRequest.personaId,
          language: coachRequest.language,
          register: coachRequest.register,
          messages: coachRequest.messages,
        });
      } catch (error) {
        const errorCode =
          error instanceof ProviderUnavailableError ? error.classification : 'unknown';
        await refundCoachTurn(db, {
          coupleId: coachRequest.coupleId,
          uid,
          reservedDayKey,
          reservedMonthKey,
        });
        emit({ outcome: 'unavailable', ...logBase, errorCode });
        throw new HttpsError('unavailable', 'The coach is temporarily unavailable.');
      }

      // (7) Crisis post-filter — the same detector (all lexicons) over the reply. A
      // hit (or a detector throw — fail-closed) discards the persona reply for the
      // help path; the cap stays consumed (the provider was paid).
      let postVerdict: CrisisVerdict;
      try {
        postVerdict = detect([truncateForScan(reply.text)]);
      } catch {
        emit({ outcome: 'help-path', language: coachRequest.language });
        return { kind: 'help', text: helpResponse(coachRequest.language), remaining };
      }
      if (postVerdict.hit) {
        emit({ outcome: 'help-path', language: coachRequest.language });
        return {
          kind: 'help',
          category: postVerdict.category,
          text: helpResponse(coachRequest.language),
          remaining,
        };
      }

      // (8) Persona reply.
      emit({
        outcome: 'reply',
        ...logBase,
        capRemainingDaily: remaining.daily,
        capRemainingMonthly: remaining.monthly,
      });
      return { kind: 'reply', text: reply.text, remaining };
    } catch (error) {
      // Outermost catch: a deliberate HttpsError propagates verbatim (static
      // message). Any OTHER escape is converted to a static internal — never a raw
      // rethrow, so the framework's own error auto-logger can't fire on request text.
      if (error instanceof HttpsError) {
        throw error;
      }
      emit({ outcome: 'internal', language: 'en', errorCode: 'unknown' });
      throw new HttpsError('internal', 'The coach is temporarily unavailable.');
    }
  };
}

/**
 * The deployed callable (Decision 1): europe-west1, App Check enforcement OFF
 * (repo-wide posture), the createInvite wiring. The default provider is
 * fail-closed, so a live deploy answers premium+capped turns with `unavailable`
 * and crisis turns with the help path — the honest posture until a provider lands.
 */
export const coachProxy = onCall(
  {
    region: FUNCTIONS_REGION,
    enforceAppCheck: false,
  },
  makeCoachProxyHandler(),
);
