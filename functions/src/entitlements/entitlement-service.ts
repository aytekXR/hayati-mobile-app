// The Firestore half of the RevenueCat mirror (M4.1, ADR-013): resolve the
// event's couple, then run ONE transaction (read subscriptions/{coupleId} →
// per-lane guard → project → write lane + derived summary). `db` is the FIRST
// param and the ONLY Firestore handle — no getFirestore() here; the shell
// resolves it and injects it (the reveal-service mold). Every decidable state is
// a TYPED outcome, never a throw; a throw is systemic (Firestore down) for the
// shell to answer 500 + let RC retry.
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import {
  Lane,
  EntitlementSummary,
  RcEvent,
  RC_ANONYMOUS_PREFIX,
  TRANSFER_TYPE,
  TransferHoldReason,
  TransferResolution,
  applyLane,
  decide,
  deriveSummary,
  gateTransfer,
  logProjection,
  planTransfer,
  projectEvent,
  revokeLane,
} from './entitlement-core';

/** Injectable clock for the lane's updatedAtMs (defaults to Date.now). */
export interface ProcessDeps {
  now?: () => number;
}

/**
 * One typed outcome per decidable path (Decision 2/3/4). `applied` carries the
 * derived summary for the log/response; the two guard skips and the resolution
 * skips carry what they resolved so far. noop-type/unprojectable are decided
 * from the payload alone, before any Firestore read.
 */
export type ProcessOutcome =
  | { decision: 'applied'; coupleId: string; uid: string; summary: EntitlementSummary }
  | { decision: 'replay-skip'; coupleId: string; uid: string }
  | { decision: 'stale-skip'; coupleId: string; uid: string }
  | { decision: 'noop-type' }
  | { decision: 'unprojectable' }
  | { decision: 'unresolvable' }
  // ADR-015: a TRANSFER revoked ≥1 loser lane (each on its own couple doc), or
  // it held (wrote nothing — every ambiguity holds by design).
  | { decision: 'transfer-revoked'; targets: Array<{ coupleId: string; uid: string }> }
  | { decision: 'transfer-hold'; reason: TransferHoldReason };

/** What identity resolution found: the couple + the originating (lane-key) uid. */
interface ResolvedCouple {
  coupleId: string;
  uid: string;
}

/**
 * Resolves the event's couple (Decision 3): scan `app_user_id`,
 * `original_app_user_id`, then `aliases[]`, skipping RC anonymous ids. The FIRST
 * candidate that resolves to an EXISTING `users/{uid}` doc ends the scan — its
 * `coupleId` (or lack of one) is the answer, NEVER fall past a real user into
 * older aliases (that could mirror a purchase onto an ex-partner's couple). A
 * real user doc without `coupleId` is the unpaired-skip; only an anonymous
 * candidate or a candidate with no user doc lets the scan continue.
 */
async function resolveCouple(db: Firestore, event: RcEvent): Promise<ResolvedCouple | null> {
  const candidates = [event.appUserId, event.originalAppUserId, ...event.aliases];
  const seen = new Set<string>();
  for (const candidate of candidates) {
    if (typeof candidate !== 'string' || candidate.length === 0) {
      continue;
    }
    if (candidate.startsWith(RC_ANONYMOUS_PREFIX)) {
      continue;
    }
    if (seen.has(candidate)) {
      continue;
    }
    seen.add(candidate);

    const snap = await db.collection('users').doc(candidate).get();
    if (!snap.exists) {
      continue;
    }
    // HARD STOP on a real user doc (Decision 3 ex-couple hazard).
    const coupleId = snap.get('coupleId');
    if (typeof coupleId === 'string' && coupleId.length > 0) {
      return { coupleId, uid: candidate };
    }
    return null;
  }
  return null;
}

/**
 * Resolves ONE transfer id independently (ADR-015 Decision 3). Unlike
 * `resolveCouple` there is no alias CHAIN to walk and nothing to hard-stop
 * against: RC never commits to whether a transfer array is one customer's alias
 * set or several distinct customers, so each id is judged on its own doc.
 */
async function resolveTransferId(db: Firestore, id: string): Promise<TransferResolution> {
  const snap = await db.collection('users').doc(id).get();
  if (!snap.exists) {
    return { id, status: 'unknown' };
  }
  const coupleId = snap.get('coupleId');
  if (typeof coupleId === 'string' && coupleId.length > 0) {
    return { id, status: 'couple', coupleId };
  }
  return { id, status: 'unpaired' };
}

/**
 * The TRANSFER path (ADR-015). A transfer is a bare pointer event — it carries
 * NO product, expiry, entitlement ids or period — so the gain half is
 * structurally unprojectable and a transfer NEVER creates or entitles a gainer's
 * lane (Decision 1). Only the loss half is actionable, and only on positive
 * evidence that the entitlement left the couple (Decision 2).
 *
 * The pre-read gate decides everything payload-decidable first (zero reads on a
 * hold), then ≤20 independent identity reads, then a pure plan. Each target
 * couple gets its OWN transaction — the couple doc is the aggregate boundary and
 * no invariant spans two couples. Partial application is safe by IDEMPOTENCE,
 * not atomicity: every write is guarded by that lane's own order key with the
 * same event.id, so if this dies between couples the shell 500s, RC retries, the
 * written couple replay-skips and the rest apply.
 */
async function processTransferEvent(
  db: Firestore,
  event: RcEvent,
  now: () => number,
): Promise<ProcessOutcome> {
  const gate = gateTransfer(event);
  if (gate.kind === 'unprojectable') {
    logger.warn('revenuecat_webhook: unprojectable transfer', logProjection(event, 'unprojectable'));
    return { decision: 'unprojectable' };
  }
  if (gate.kind === 'hold') {
    return holdTransfer(event, gate.reason);
  }

  const [from, to] = await Promise.all([
    Promise.all(gate.fromIds.map((id) => resolveTransferId(db, id))),
    Promise.all(gate.toIds.map((id) => resolveTransferId(db, id))),
  ]);

  const plan = planTransfer(from, to);
  if (plan.kind === 'hold') {
    return holdTransfer(event, plan.reason);
  }

  for (const target of plan.targets) {
    const ref = db.collection('subscriptions').doc(target.coupleId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const lanes = readLanes(snap);
      // A tombstone is written even when the lane does not exist yet: otherwise a
      // late INITIAL_PURCHASE (older ts) would resurrect the moved-away entitlement.
      const nextLanes = revokeLane(lanes, target.uid, event, now());
      if (nextLanes === lanes) {
        return; // replay/stale on this lane — no write, and no other lane is touched
      }
      tx.set(ref, {
        ...deriveSummary(nextLanes),
        lanes: nextLanes,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    // One PII-safe line PER target — the projection's shape is unchanged, so the
    // transfer arrays (user identifiers) never reach a log.
    logger.info(
      'revenuecat_webhook: transfer revoked',
      logProjection(event, 'transfer-revoked', target.coupleId),
    );
  }

  return { decision: 'transfer-revoked', targets: plan.targets };
}

/** A held transfer writes NOTHING and returns 200 — a loud, counted skip. */
function holdTransfer(event: RcEvent, reason: TransferHoldReason): ProcessOutcome {
  logger.info(
    'revenuecat_webhook: transfer hold',
    logProjection(event, `transfer-hold:${reason}`),
  );
  return { decision: 'transfer-hold', reason };
}

/** Reads the trusted (sole-writer) lanes map off the mirror doc, or {} if absent. */
function readLanes(snap: FirebaseFirestore.DocumentSnapshot): Record<string, Lane> {
  const lanes = snap.get('lanes');
  if (lanes === undefined || lanes === null || typeof lanes !== 'object') {
    return {};
  }
  return lanes as Record<string, Lane>;
}

/**
 * Processes one authenticated RC webhook event onto `subscriptions/{coupleId}`.
 * Projection is decided first (pure, cheap): a TEST/unknown type or an
 * unprojectable payload returns WITHOUT touching Firestore — it never reads users
 * nor writes the mirror. Only a real projection resolves identity and enters the
 * transaction, where the mirror-doc read joins the read set so concurrent
 * deliveries (same lane or sibling partner's lane) serialize and the guards are
 * race-safe (Decision 4 latch).
 */
export async function processRevenueCatEvent(
  db: Firestore,
  event: RcEvent,
  deps: ProcessDeps = {},
): Promise<ProcessOutcome> {
  const now = deps.now ?? Date.now;

  // TRANSFER owns its own identity model (transferred_from/to, no app_user_id) and
  // its own projection (revoke-only, never a grant) — ADR-015. It must branch
  // BEFORE the lifecycle projection, which would classify it a no-op type.
  if (event.type === TRANSFER_TYPE) {
    return processTransferEvent(db, event, now);
  }

  const projection = projectEvent(event);
  if (projection.kind === 'noop') {
    logger.info('revenuecat_webhook: no-op type', logProjection(event, 'noop-type'));
    return { decision: 'noop-type' };
  }
  if (projection.kind === 'unprojectable') {
    // Authenticated as RC, so possibly schema drift — never mutate on doubt, and
    // never burn RC's retry budget on a deterministic parse failure (200 skip).
    logger.warn('revenuecat_webhook: unprojectable event', logProjection(event, 'unprojectable'));
    return { decision: 'unprojectable' };
  }

  const resolved = await resolveCouple(db, event);
  if (resolved === null) {
    // Unpaired / anonymous / no user doc: a counted loud skip returning 200. RC
    // would drop a non-200 after ~155min anyway, and later pairing (M4.2 flow)
    // is what closes the purchase-before-pairing gap for real.
    logger.warn('revenuecat_webhook: unresolvable identity', logProjection(event, 'unresolvable'));
    return { decision: 'unresolvable' };
  }
  const { coupleId, uid } = resolved;
  const ref = db.collection('subscriptions').doc(coupleId);

  const outcome = await db.runTransaction<ProcessOutcome>(async (tx) => {
    const snap = await tx.get(ref);
    const lanes = readLanes(snap);
    const nextLanes = applyLane(lanes, uid, event, now());
    if (nextLanes === lanes) {
      // No change: projection was 'project' (checked above), so this is a guard
      // skip and the lane MUST exist — re-decide only to label replay vs stale.
      const existing = lanes[uid];
      const label = decide(
        { lastEventTimestampMs: existing.lastEventTimestampMs, lastEventId: existing.lastEventId },
        event,
      );
      return label === 'replay-skip'
        ? { decision: 'replay-skip', coupleId, uid }
        : { decision: 'stale-skip', coupleId, uid };
    }

    const summary = deriveSummary(nextLanes);
    // Full-doc set: this Function is the sole writer, so the whole Decision-5
    // shape (summary fields + lanes + updatedAt) is reconstructed each apply.
    tx.set(ref, { ...summary, lanes: nextLanes, updatedAt: FieldValue.serverTimestamp() });
    return { decision: 'applied', coupleId, uid, summary };
  });

  logOutcome(event, outcome);
  return outcome;
}

/**
 * One structured line per decision, PII-safe via logProjection. Only ever
 * reached with a transaction outcome (applied / replay-skip / stale-skip) — the
 * payload-only skips (noop-type/unprojectable/unresolvable) log at their own
 * early returns and fall through the default here.
 */
function logOutcome(event: RcEvent, outcome: ProcessOutcome): void {
  switch (outcome.decision) {
    case 'applied':
      logger.info('revenuecat_webhook: applied', {
        ...logProjection(event, 'applied', outcome.coupleId),
        entitled: outcome.summary.entitled,
      });
      return;
    case 'replay-skip':
    case 'stale-skip':
      // Normal idempotency / out-of-order arrival, logged for trace.
      logger.info(
        'revenuecat_webhook: guard skip',
        logProjection(event, outcome.decision, outcome.coupleId),
      );
      return;
    default:
      return;
  }
}
