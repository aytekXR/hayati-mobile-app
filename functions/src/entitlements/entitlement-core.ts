// Pure decision core for the RevenueCat → couple-entitlement mirror (M4.1,
// ADR-013). Everything here is a total function over plain values — NO Firestore
// imports, so the parsing/projection/guard/summary logic is exhaustively unit-
// and property-testable without the emulator (the streak.ts mold). The service
// (entitlement-service.ts) resolves identity + drives the transaction; the shell
// (revenuecat-webhook.ts) owns HTTP. This module owns WHAT an event means.

/**
 * The always-present envelope fields RC guarantees on every webhook event, plus
 * the optional per-type fields the projection consumes. Identity fields
 * (appUserId/originalAppUserId/aliases) ride along for the SERVICE's resolution;
 * the projection ignores them. The two entitled-until candidates stay `unknown`
 * because their validity is a per-type concern decided at projection time (a
 * non-numeric expiration is `unprojectable`, not envelope-malformed).
 */
export interface RcEvent {
  type: string;
  id: string;
  eventTimestampMs: number;
  appUserId: string;
  originalAppUserId: string | null;
  aliases: string[];
  environment: string | null;
  store: string | null;
  productId: string | null;
  newProductId: string | null;
  periodType: string | null;
  /** Validated at projection (optionalMs): number | null = fine, else unprojectable. */
  expirationAtMs: unknown;
  /** BILLING_ISSUE only; same validation. Always present there, but can be null. */
  gracePeriodExpirationAtMs: unknown;
  entitlementIds: string[] | null;
}

/** parseRcEvent's three-way result: the body contract (ADR-013 Decision 2). */
export type RcParseResult =
  | { status: 'malformed' }
  | { status: 'ok'; event: RcEvent };

/** The entitlement facts one event projects (Decision 5 lane shape, minus bookkeeping). */
export interface LaneProjection {
  entitled: boolean;
  productId: string | null;
  periodType: string | null;
  /** entitled-until epoch ms; null = non-expiring (never a stand-in for "unknown"). */
  expiresAtMs: number | null;
  willRenew: boolean;
  store: string | null;
  environment: string | null;
  entitlementIds: string[] | null;
}

/** projectEvent's result: a mirror write, a logged no-op, or a counted skip. */
export type Projection =
  | { kind: 'project'; lane: LaneProjection }
  | { kind: 'noop' }
  | { kind: 'unprojectable' };

/** A stored per-uid lane: the projection plus the total-order key and write time. */
export interface Lane extends LaneProjection {
  lastEventId: string;
  lastEventTimestampMs: number;
  updatedAtMs: number;
}

/** The couple-level summary the app reads (Decision 5); lanes stay server-only. */
export interface EntitlementSummary {
  entitled: boolean;
  productId: string | null;
  periodType: string | null;
  expiresAtMs: number | null;
  willRenew: boolean;
  store: string | null;
  environment: string | null;
}

/** The zero-state a couple with no lanes reads as (absent doc = free tier). */
export const FREE_SUMMARY: EntitlementSummary = {
  entitled: false,
  productId: null,
  periodType: null,
  expiresAtMs: null,
  willRenew: false,
  store: null,
  environment: null,
};

/** RC anonymous ids (`$RCAnonymousID:<hex>`) are never a Firebase uid. */
export const RC_ANONYMOUS_PREFIX = '$RCAnonymousID:';

// --- envelope parsing -------------------------------------------------------

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** A non-empty string, else null — display fields never carry '' or a wrong type. */
function asString(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

/** String elements of an array, else null for a non-array (null/absent/wrong type). */
function asStringArray(value: unknown): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  return value.filter((element): element is string => typeof element === 'string');
}

/**
 * Validates the RC webhook ENVELOPE only (Decision 2 body contract): the fields
 * that must exist on EVERY event — `event` object, string `type`/`id`, numeric
 * `event_timestamp_ms`, string `app_user_id`. A shape surprise here is a typed
 * `malformed` result (the shell answers 400), never a thrown 500. Per-type
 * fields are passed through untouched for the projection to judge.
 */
export function parseRcEvent(body: unknown): RcParseResult {
  if (!isRecord(body)) {
    return { status: 'malformed' };
  }
  const event = body.event;
  if (!isRecord(event)) {
    return { status: 'malformed' };
  }
  const { type, id, event_timestamp_ms: ts, app_user_id: appUserId } = event;
  if (typeof type !== 'string' || type.length === 0) {
    return { status: 'malformed' };
  }
  if (typeof id !== 'string' || id.length === 0) {
    return { status: 'malformed' };
  }
  if (typeof ts !== 'number' || !Number.isFinite(ts)) {
    return { status: 'malformed' };
  }
  if (typeof appUserId !== 'string' || appUserId.length === 0) {
    return { status: 'malformed' };
  }
  return {
    status: 'ok',
    event: {
      type,
      id,
      eventTimestampMs: ts,
      appUserId,
      originalAppUserId: asString(event.original_app_user_id),
      aliases: asStringArray(event.aliases) ?? [],
      environment: asString(event.environment),
      store: asString(event.store),
      productId: asString(event.product_id),
      newProductId: asString(event.new_product_id),
      periodType: asString(event.period_type),
      expirationAtMs: event.expiration_at_ms,
      gracePeriodExpirationAtMs: event.grace_period_expiration_at_ms,
      entitlementIds: asStringArray(event.entitlement_ids),
    },
  };
}

// --- projection (Decision 2 table) ------------------------------------------

type OptionalMs = { ok: true; value: number | null } | { ok: false };

/**
 * An entitled-until candidate: absent/null → `null` (non-expiring), a finite
 * number → itself, anything else → `{ok:false}` (unprojectable). The null vs
 * not-ok distinction is the whole point — a null card grace maps to a real
 * fallback, a garbage value never mutates the mirror.
 */
function optionalMs(value: unknown): OptionalMs {
  if (value === null || value === undefined) {
    return { ok: true, value: null };
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return { ok: true, value };
  }
  return { ok: false };
}

/**
 * willRenew pinned per type (review finding — RC events carry no uniform renewal
 * flag). Membership in this table ALSO defines "a projecting type": a type
 * absent here is TEST/TRANSFER/future → a logged no-op, never a mirror write.
 */
const PROJECTING_WILL_RENEW: Readonly<Record<string, boolean>> = {
  INITIAL_PURCHASE: true,
  RENEWAL: true,
  PRODUCT_CHANGE: true,
  UNCANCELLATION: true,
  SUBSCRIPTION_EXTENDED: true,
  // Billing retry in progress — renewal still being attempted, so willRenew true.
  BILLING_ISSUE: true,
  NON_RENEWING_PURCHASE: false,
  // Auto-renew OFF but STILL entitled until expiry (RC: don't revoke on cancel).
  CANCELLATION: false,
  SUBSCRIPTION_PAUSED: false,
  // The ONLY revoking event (entitled → false); willRenew false.
  EXPIRATION: false,
};

/**
 * The entitled-until timestamp for a projecting event. BILLING_ISSUE alone reads
 * `grace_period_expiration_at_ms ?? expiration_at_ms`: the grace field is always
 * present on that type but CAN be null (no grace configured), and a null grace
 * MUST fall back to expiration — never collapse into the null=non-expiring
 * sentinel, which would mint permanent free premium on a failed card (review
 * finding). Every other type reads expiration_at_ms directly.
 */
function resolveEntitledUntil(event: RcEvent): OptionalMs {
  if (event.type === 'BILLING_ISSUE') {
    const grace = optionalMs(event.gracePeriodExpirationAtMs);
    if (!grace.ok) {
      return grace;
    }
    if (grace.value !== null) {
      return grace;
    }
    return optionalMs(event.expirationAtMs);
  }
  return optionalMs(event.expirationAtMs);
}

/**
 * Projects one event to its lane facts (Decision 2), or classifies it as a
 * logged no-op (TEST/unknown type) or a counted `unprojectable` skip (known type
 * whose entitled-until field is a non-numeric surprise — schema drift; never
 * mutate on doubt). Every entitled-until candidate is an ABSOLUTE timestamp in
 * THIS event, so the projection of the total-order-maximal event IS the lane
 * state — what makes the out-of-order guard convergent by construction.
 */
export function projectEvent(event: RcEvent): Projection {
  const willRenew = PROJECTING_WILL_RENEW[event.type];
  if (willRenew === undefined) {
    return { kind: 'noop' };
  }
  const entitledUntil = resolveEntitledUntil(event);
  if (!entitledUntil.ok) {
    return { kind: 'unprojectable' };
  }
  const productId =
    event.type === 'PRODUCT_CHANGE'
      ? // new_product_id is omitted-when-null; falling back keeps the CURRENT
        // product instead of dropping it (product_id stays the OLD product here).
        event.newProductId ?? event.productId
      : event.productId;
  return {
    kind: 'project',
    lane: {
      entitled: event.type !== 'EXPIRATION',
      productId,
      periodType: event.periodType,
      expiresAtMs: entitledUntil.value,
      willRenew,
      store: event.store,
      environment: event.environment,
      entitlementIds: event.entitlementIds,
    },
  };
}

// --- total-order guard (Decision 4) -----------------------------------------

/** The lexicographic order key a lane advances over: (event_timestamp_ms, id). */
export interface OrderKey {
  lastEventTimestampMs: number;
  lastEventId: string;
}

export type GuardDecision = 'apply' | 'replay-skip' | 'stale-skip';

/** Compare (ts, id) lexicographically: <0 a-before-b, 0 equal, >0 a-after-b. */
function compareOrder(
  a: { ts: number; id: string },
  b: { ts: number; id: string },
): number {
  if (a.ts !== b.ts) {
    return a.ts < b.ts ? -1 : 1;
  }
  if (a.id !== b.id) {
    return a.id < b.id ? -1 : 1;
  }
  return 0;
}

/**
 * Last-writer-wins over the total order `(event_timestamp_ms, event.id)`: apply
 * iff STRICTLY greater than the lane's current key. Equal → `replay-skip` (a
 * retry reuses (ts, id)); less → `stale-skip` (an out-of-order older event). The
 * id — a UUID — breaks same-millisecond ties deterministically, so equal-ts
 * distinct events resolve to the same winner regardless of arrival order. There
 * is NO processed-ids FIFO: the order is O(1) lane state and convergent.
 */
export function decide(lane: OrderKey | null, event: RcEvent): GuardDecision {
  if (lane === null) {
    return 'apply';
  }
  const cmp = compareOrder(
    { ts: event.eventTimestampMs, id: event.id },
    { ts: lane.lastEventTimestampMs, id: lane.lastEventId },
  );
  if (cmp > 0) {
    return 'apply';
  }
  return cmp === 0 ? 'replay-skip' : 'stale-skip';
}

/**
 * Applies one event to a uid-keyed lanes map: guard + projection folded into a
 * new map, or the SAME reference when the event is a no-op / unprojectable /
 * guard-skip (the caller uses referential identity to detect "no change").
 * Pure and total — the property test folds random permutations through it and
 * the service reuses it inside its transaction, so both share ONE definition of
 * convergence. `updatedAtMs` is the caller's clock (0 in the property test,
 * where it must not perturb equality; Date.now() in the service).
 */
export function applyLane(
  lanes: Record<string, Lane>,
  uid: string,
  event: RcEvent,
  updatedAtMs: number,
): Record<string, Lane> {
  const projection = projectEvent(event);
  if (projection.kind !== 'project') {
    return lanes;
  }
  const existing = lanes[uid];
  const key: OrderKey | null = existing
    ? { lastEventTimestampMs: existing.lastEventTimestampMs, lastEventId: existing.lastEventId }
    : null;
  if (decide(key, event) !== 'apply') {
    return lanes;
  }
  return {
    ...lanes,
    [uid]: {
      ...projection.lane,
      lastEventId: event.id,
      lastEventTimestampMs: event.eventTimestampMs,
      updatedAtMs,
    },
  };
}

// --- couple summary (Decision 4/5) ------------------------------------------

/** null (non-expiring) ranks highest; otherwise later expiry wins. */
function compareExpiry(a: number | null, b: number | null): number {
  if (a === b) {
    return 0;
  }
  if (a === null) {
    return 1;
  }
  if (b === null) {
    return -1;
  }
  return a < b ? -1 : 1;
}

/**
 * Ranks lane `a` against `b` for display selection (>0 = a outranks b): entitled
 * lanes first, then latest expiresAtMs (null = non-expiring ranks highest), then
 * the lane's (lastEventTimestampMs, lastEventId) order key as the final,
 * deterministic tie-break.
 */
function compareLaneRank(a: Lane, b: Lane): number {
  if (a.entitled !== b.entitled) {
    return a.entitled ? 1 : -1;
  }
  const byExpiry = compareExpiry(a.expiresAtMs, b.expiresAtMs);
  if (byExpiry !== 0) {
    return byExpiry;
  }
  return compareOrder(
    { ts: a.lastEventTimestampMs, id: a.lastEventId },
    { ts: b.lastEventTimestampMs, id: b.lastEventId },
  );
}

/**
 * Derives the couple summary the app reads (Decision 4): entitled iff ANY lane
 * is entitled ("one purchase entitles both"; the couple downgrades only when the
 * last entitled lane expires — "expiry downgrades both"). Display fields come
 * from the deterministically-chosen winning lane. A pure function of the lanes
 * map, so the whole mirror doc converges with the lanes it is derived from.
 */
export function deriveSummary(lanes: Record<string, Lane>): EntitlementSummary {
  const list = Object.values(lanes);
  if (list.length === 0) {
    return FREE_SUMMARY;
  }
  const winner = list.reduce((best, lane) => (compareLaneRank(lane, best) > 0 ? lane : best));
  return {
    entitled: list.some((lane) => lane.entitled),
    productId: winner.productId,
    periodType: winner.periodType,
    expiresAtMs: winner.expiresAtMs,
    willRenew: winner.willRenew,
    store: winner.store,
    environment: winner.environment,
  };
}

// --- PII-safe logging (Decision 2) ------------------------------------------

/** The ONLY fields any webhook log line may carry — never the body, never
 *  subscriber_attributes ($email PII), never alias lists. */
export interface LogFields {
  type: string;
  id: string;
  environment: string | null;
  decision: string;
  coupleId?: string;
}

/**
 * The single log-projection helper every handler/service log line goes through:
 * `{type, id, environment, decision, coupleId?}` and nothing else. RC events
 * carry `subscriber_attributes` ($email/$phoneNumber) and alias lists — this
 * projection is the auditable one spot that guarantees neither is ever logged.
 */
export function logProjection(
  event: RcEvent,
  decision: string,
  coupleId?: string,
): LogFields {
  const fields: LogFields = {
    type: event.type,
    id: event.id,
    environment: event.environment,
    decision,
  };
  if (coupleId !== undefined) {
    fields.coupleId = coupleId;
  }
  return fields;
}
