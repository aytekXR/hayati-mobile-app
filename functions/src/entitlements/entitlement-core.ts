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
  /**
   * NULL ON `TRANSFER` ONLY (ADR-015 Finding 0). RC's subscriber-identity field
   * group (app_user_id/original_app_user_id/aliases) does NOT apply to TRANSFER —
   * a real transfer body carries `transferred_from`/`transferred_to` instead. The
   * envelope contract is therefore PER-TYPE: `parseRcEvent` still rejects a
   * lifecycle event without an app_user_id (400), but a TRANSFER without one is
   * the documented shape, not malformed.
   */
  appUserId: string | null;
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
  /** TRANSFER only: the ids the entitlements are TAKEN FROM (the losers). */
  transferredFrom: string[] | null;
  /** TRANSFER only: the ids RECEIVING them (the gainers). Never written to. */
  transferredTo: string[] | null;
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

/** The RC event type that moves a subscription between subscribers (ADR-015). */
export const TRANSFER_TYPE = 'TRANSFER';

/**
 * Max ids we will RESOLVE per transfer array (ADR-015 Decision 3). Applied at a
 * PRE-READ gate — after the pure anon-filter/dedupe, before any Firestore read —
 * so a hostile payload costs ZERO reads and an accepted transfer costs ≤20.
 */
export const MAX_TRANSFER_IDS = 10;

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
 * Validates the RC webhook ENVELOPE only (ADR-013 Decision 2 body contract, as
 * amended by ADR-015): the fields that must exist on EVERY event — `event`
 * object, string `type`/`id`, numeric `event_timestamp_ms` — plus a non-empty
 * `app_user_id` on every type EXCEPT `TRANSFER`.
 *
 * The identity contract is PER-TYPE because RC's own field tables are: the
 * subscriber-identity group does not apply to `TRANSFER`, whose real body
 * carries `transferred_from`/`transferred_to` and NO `app_user_id`. Before
 * ADR-015 this function classified every genuine transfer as `malformed` — a
 * 400 that burned RC's 5-retry budget and dropped the event (Finding 0). A
 * LIFECYCLE event without an `app_user_id` is still malformed: the exception is
 * exactly one type wide, never a blanket relaxation.
 *
 * A shape surprise here is a typed `malformed` result (the shell answers 400),
 * never a thrown 500. Per-type fields are passed through untouched for the
 * projection (or, for TRANSFER, the transfer path) to judge.
 */
export function parseRcEvent(body: unknown): RcParseResult {
  if (!isRecord(body)) {
    return { status: 'malformed' };
  }
  const event = body.event;
  if (!isRecord(event)) {
    return { status: 'malformed' };
  }
  const { type, id, event_timestamp_ms: ts, app_user_id: rawAppUserId } = event;
  if (typeof type !== 'string' || type.length === 0) {
    return { status: 'malformed' };
  }
  if (typeof id !== 'string' || id.length === 0) {
    return { status: 'malformed' };
  }
  if (typeof ts !== 'number' || !Number.isFinite(ts)) {
    return { status: 'malformed' };
  }
  const appUserId = asString(rawAppUserId);
  if (appUserId === null && type !== TRANSFER_TYPE) {
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
      transferredFrom: asStringArray(event.transferred_from),
      transferredTo: asStringArray(event.transferred_to),
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

// --- TRANSFER (ADR-015) ------------------------------------------------------

/**
 * The lane a TRANSFER writes for a LOSER (ADR-015 Decision 4). A PURE function
 * of the event: it deliberately does NOT read the loser's previous lane.
 *
 * That restraint is load-bearing. A lane value derived from another lane value
 * stops being the projection of the total-order-maximal event, and the mirror
 * stops converging under reordering — which is also why the intuitive "MOVE the
 * lane to the gainer" design is rejected: in-order [PURCHASE, TRANSFER] would
 * hand the gainer the purchase's facts, while the reordered [TRANSFER, PURCHASE]
 * finds nothing to move and then stale-skips the purchase. Two arrangements of
 * one event multiset, two different mirrors — one of which silently drops a
 * paying couple to free.
 *
 * `expiresAtMs` is the transfer instant: honest ("entitled until the moment it
 * moved"), non-null, and therefore never the null=non-expiring sentinel.
 */
export function revokedLane(event: RcEvent): LaneProjection {
  return {
    entitled: false,
    productId: null,
    periodType: null,
    expiresAtMs: event.eventTimestampMs,
    willRenew: false, // renewals belong to the gainer now
    store: event.store, // "Sometimes" present on a transfer → may be null
    environment: event.environment,
    entitlementIds: null,
  };
}

/**
 * `applyLane`'s twin for the revoke half of a TRANSFER: the SAME total-order
 * guard on the target lane's own key, the SAME same-reference-on-skip contract.
 * So a lane stays a last-writer-wins register over `(event_timestamp_ms, id)`
 * whichever projection wrote it, and the convergence invariant of ADR-013
 * Decision 4 survives the addition of transfers untouched.
 *
 * A tombstone is written even when the lane does NOT exist yet: otherwise a
 * late-arriving INITIAL_PURCHASE (older ts) would resurrect an entitlement the
 * transfer already moved away.
 */
export function revokeLane(
  lanes: Record<string, Lane>,
  uid: string,
  event: RcEvent,
  updatedAtMs: number,
): Record<string, Lane> {
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
      ...revokedLane(event),
      lastEventId: event.id,
      lastEventTimestampMs: event.eventTimestampMs,
      updatedAtMs,
    },
  };
}

/** What one `users/{id}` lookup found for a transfer id (ADR-015 Decision 3). */
export type TransferResolution =
  | { id: string; status: 'unknown' }
  | { id: string; status: 'unpaired' }
  | { id: string; status: 'couple'; coupleId: string };

/** The ids a transfer will actually resolve, or the reason it stops before reading. */
export type TransferGate =
  | { kind: 'resolve'; fromIds: string[]; toIds: string[] }
  | { kind: 'unprojectable' }
  | { kind: 'hold'; reason: TransferHoldReason };

export type TransferHoldReason =
  | 'internal'
  | 'ambiguous-destination'
  | 'no-loser'
  | 'oversized';

/** The transfer plan: revoke named lanes on named couples, or hold (write nothing). */
export type TransferPlan =
  | { kind: 'revoke'; targets: Array<{ coupleId: string; uid: string }> }
  | { kind: 'hold'; reason: TransferHoldReason };

function isAnonymous(id: string): boolean {
  return id.startsWith(RC_ANONYMOUS_PREFIX);
}

function dedupe(ids: string[]): string[] {
  return [...new Set(ids.filter((id) => id.length > 0))];
}

/**
 * The PRE-READ gate (ADR-015 Decision 3): everything decidable from the payload
 * alone, so a hostile or unplaceable transfer costs ZERO Firestore reads and an
 * accepted one costs at most 2 × MAX_TRANSFER_IDS.
 *
 * The two sides treat an RC anonymous id differently, deliberately:
 *  - `from`: filtered out (never a Firebase uid ⇒ neither a lane key nor evidence
 *    of a couple; dropping it costs nothing).
 *  - `to`: an anon id is an UNPLACEABLE DESTINATION ⇒ hold. It may be the loser
 *    themselves mid-reinstall (delete app → anon id → store auto-restore →
 *    logIn(uid)). Filtering it away and calling the rest "fully known" would
 *    revoke on `to = [anon, uidB]` — a false downgrade of a paying couple, the
 *    one outcome this design refuses (Decision 2). RC never commits to what the
 *    arrays contain, and that premise has to cut both ways.
 *
 * Filter+dedupe run BEFORE the cap because they are pure: capping the raw array
 * would hold on routine anonymous-alias accretion (the app mints a fresh anon id
 * on every sign-out) and leave the revoke path inert for exactly the
 * identity-churning accounts that generate transfers.
 */
export function gateTransfer(event: RcEvent): TransferGate {
  const rawFrom = event.transferredFrom;
  const rawTo = event.transferredTo;
  if (rawFrom === null || rawTo === null) {
    // Per-type schema drift on a body that authenticated as RC: a counted 200
    // skip, never a 400 (ADR-013's never-mutate-on-doubt philosophy).
    return { kind: 'unprojectable' };
  }

  const toIds = dedupe(rawTo);
  if (toIds.length === 0 || toIds.some(isAnonymous)) {
    return { kind: 'hold', reason: 'ambiguous-destination' };
  }

  const fromIds = dedupe(rawFrom).filter((id) => !isAnonymous(id));
  if (fromIds.length > MAX_TRANSFER_IDS || toIds.length > MAX_TRANSFER_IDS) {
    return { kind: 'hold', reason: 'oversized' };
  }
  if (fromIds.length === 0) {
    return { kind: 'hold', reason: 'no-loser' };
  }
  return { kind: 'resolve', fromIds, toIds };
}

/**
 * The whole transfer decision, as a pure function of the resolved id lists
 * (ADR-015 Decision 3). The standing rule: revoke the loser's lane iff the
 * destination is FULLY KNOWN and does not include the loser's couple — every
 * ambiguity holds, because a false revoke instantly strips a paying couple while
 * a missed revoke only leaks the tail of a period someone actually paid for.
 *
 * The `to` side is used ONLY to answer "did the entitlement stay inside this
 * couple?" and to detect ambiguity. It is NEVER written: a TRANSFER carries no
 * product and no expiry, so a gainer's lane could only be fabricated (Decision 1).
 */
export function planTransfer(
  from: TransferResolution[],
  to: TransferResolution[],
): TransferPlan {
  if (to.some((resolution) => resolution.status === 'unknown')) {
    return { kind: 'hold', reason: 'ambiguous-destination' };
  }
  const toCoupleIds = new Set(
    to.flatMap((resolution) => (resolution.status === 'couple' ? [resolution.coupleId] : [])),
  );

  const losers = from.flatMap((resolution) =>
    resolution.status === 'couple' ? [{ coupleId: resolution.coupleId, uid: resolution.id }] : [],
  );
  if (losers.length === 0) {
    return { kind: 'hold', reason: 'no-loser' };
  }

  const targets = losers.filter((loser) => !toCoupleIds.has(loser.coupleId));
  if (targets.length === 0) {
    // Every loser's couple is also a destination: the entitlement did not leave
    // the couple, only the RC subscriber holding it changed. The mirror is
    // couple-scoped, so this is a no-op — revoking here would downgrade a paying
    // couple on a shared-Apple-ID restore.
    return { kind: 'hold', reason: 'internal' };
  }
  return { kind: 'revoke', targets };
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
