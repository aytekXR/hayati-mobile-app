// The pure decision core for the FCM token lifecycle (ADR-042 Decision 1).
//
// `users/{uid}.fcmTokens` is server-owned: rules forbid a client from minting it
// at create or touching it at update, so the registerPushToken /
// unregisterPushToken callables are its only writers. Everything those callables
// decide is decided HERE — request shape, the stored array's discipline, and the
// PII-free log projection — so the rules are provable with no Firestore, no FCM
// and no device, which is the same trade ADR-012 D3 made for the send side.
//
// Why the array has discipline at all: it is unbounded on the wire and a client
// cannot be trusted to bound its own. `entitlements/entitlement-core.ts:472`
// (`dedupe`) is the filter-empties + `Set` precedent and all of it; the cap is
// this ADR's own decision, because `MAX_TRANSFER_IDS` at `:511` is a pre-read
// REJECT gate and rejecting an oversized input is not evicting from a stored
// array.

/**
 * A generous ceiling on a single token. FCM registration tokens run ~163
 * characters today, but the format is opaque and vendor-owned, so this bound
 * exists to stop a client posting a megabyte into a user document — not to
 * second-guess Apple or Google. A legitimate token must never hit it.
 */
export const MAX_FCM_TOKEN_LENGTH = 4096;

/**
 * The most devices one account keeps live (ADR-042 D1). A phone, a tablet, and
 * room for a replaced handset whose token has not yet aged out. A sixth
 * registration drops element 0.
 */
export const MAX_FCM_TOKENS_PER_USER = 5;

export type PushTokenValidation =
  | { ok: true; token: string }
  | { ok: false; reason: 'not-object' | 'bad-token' };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

/**
 * The request body for both callables: `{ token: string }`, nothing else
 * accepted. Trims, because a client that pads a token would otherwise store a
 * string that can never receive a push while occupying a cap slot forever —
 * whitespace-only is emptiness in a disguise.
 */
export function validatePushTokenRequest(body: unknown): PushTokenValidation {
  if (!isRecord(body)) {
    return { ok: false, reason: 'not-object' };
  }
  const raw = body.token;
  if (typeof raw !== 'string') {
    return { ok: false, reason: 'bad-token' };
  }
  const token = raw.trim();
  if (token.length === 0 || token.length > MAX_FCM_TOKEN_LENGTH) {
    return { ok: false, reason: 'bad-token' };
  }
  return { ok: true, token };
}

/**
 * The stored array, cleaned. Absent / non-array / junk shapes collapse to `[]`,
 * matching `recipients.fcmTokensOf` — the reader and the writer must agree, or
 * the writer stores entries the sender silently drops.
 *
 * De-duplication keeps the LAST occurrence, so a token's position tracks how
 * recently it was registered rather than when it was first seen. That is what
 * makes the cap behave like least-recently-registered: a device that still opens
 * the app keeps moving to the back, and a device in a drawer drifts to element 0.
 */
export function sanitizeTokens(field: unknown): string[] {
  if (!Array.isArray(field)) {
    return [];
  }
  const clean = field.filter(
    (token): token is string => typeof token === 'string' && token.trim().length > 0,
  );
  // Reverse → Set (keeps first-seen, i.e. last in the original) → reverse back.
  return [...new Set([...clean].reverse())].reverse();
}

/**
 * The array after `token` is registered: cleaned, the token moved to the end
 * (idempotent — the app registers on every launch, so a growing array would let
 * one device consume the whole cap in five days), then bounded to
 * `MAX_FCM_TOKENS_PER_USER` by dropping from the FRONT.
 *
 * The cap is a bound, not a correctness mechanism. If a sixth device evicts a
 * first, that first device stops receiving pushes and nothing tells it so. That
 * is acceptable only because re-registration is cheap and happens on every
 * launch; it would not be acceptable if registration were rare.
 */
export function applyTokenRegistration(field: unknown, token: string): string[] {
  const withoutToken = sanitizeTokens(field).filter((existing) => existing !== token);
  const next = [...withoutToken, token];
  // slice(-N) bounds an array that arrived over-full as well as the increment —
  // the stored value is data, and data can predate any rule we impose on it.
  return next.slice(-MAX_FCM_TOKENS_PER_USER);
}

/**
 * The array after `token` is removed. Removes EVERY copy: a duplicate that
 * survived a sign-out would keep delivering the next user's pushes to the
 * previous user's phone, which is the privacy defect this whole decision exists
 * to close.
 */
export function applyTokenRemoval(field: unknown, token: string): string[] {
  return sanitizeTokens(field).filter((existing) => existing !== token);
}

export type PushTokenOp = 'registerPushToken' | 'unregisterPushToken';

export type PushTokenOutcome =
  | 'registered'
  | 'removed'
  | 'unauthenticated'
  | 'invalid'
  | 'profile-missing'
  | 'internal';

/**
 * The ONLY fields a push-token log line may carry — the `logDataRightsEvent`
 * discipline (ADR-019 D2), and for a sharper reason here: the token IS an
 * identifier. It addresses one physical device and is the credential for
 * delivering to it, so a log line carrying one would defeat the point of making
 * the field server-owned. There is deliberately no `uid` and no `token` field;
 * the type signature is the guarantee.
 */
export interface PushTokenEventLog {
  op: PushTokenOp;
  outcome: PushTokenOutcome;
  latencyMs?: number;
}

/** Identity by construction — the projection cannot widen without the type widening. */
export function logPushTokenEvent(event: PushTokenEventLog): PushTokenEventLog {
  return event.latencyMs === undefined
    ? { op: event.op, outcome: event.outcome }
    : { op: event.op, outcome: event.outcome, latencyMs: event.latencyMs };
}
