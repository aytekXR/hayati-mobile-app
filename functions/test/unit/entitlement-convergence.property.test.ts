// M4.1 convergence property (ADR-013 Decision 4) — the entitlement analog of
// the M3.4 streak property test. RC gives NO cross-event ordering guarantee and
// re-delivers events (retries reuse the same id + payload), so the mirror MUST
// converge: any permutation + duplication of an event set has to land on the
// projection of the total-order-maximal event per uid. The generator
// DELIBERATELY draws colliding timestamps (a 1..3 range) so equal-ts distinct
// events — same-millisecond store bursts — are the common case, forcing the
// (ts, id) tie-break to carry the determinism.
//
// M4.3 (ADR-015) widens the world to TWO COUPLES and mixes TRANSFER events into
// the multiset. A transfer is not a lifecycle event: it revokes the loser's lane
// (a tombstone that is a pure projection of the transfer itself) and NEVER
// entitles a gainer. Both facts are load-bearing for convergence, and this
// property is what enforces them: the "move the lane to the gainer" and "copy
// the loser's facts into the tombstone" designs both make a lane value depend on
// ANOTHER lane's value, which makes the fold order-dependent — and this test
// fails on them by construction.
import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

import {
  EntitlementSummary,
  Lane,
  RcEvent,
  TransferResolution,
  applyLane,
  deriveSummary,
  gateTransfer,
  planTransfer,
  projectEvent,
  revokeLane,
} from '../../src/entitlements/entitlement-core';

/** A static two-couple world: uid-a/uid-b in couple-1, uid-c/uid-d in couple-2. */
const WORLD: Record<string, string> = {
  'uid-a': 'couple-1',
  'uid-b': 'couple-1',
  'uid-c': 'couple-2',
  'uid-d': 'couple-2',
};
const UIDS = Object.keys(WORLD);
const COUPLES = ['couple-1', 'couple-2'];

interface LifecycleSpec {
  kind: 'lifecycle';
  uid: string;
  ts: number;
  type: string;
  product: string | null;
  newProduct: string | null;
  exp: number | null;
  grace: number | null;
  entitlementIds: string[] | null;
  /** When true on a projecting type, poisons expiration → an unprojectable event
   *  (must be ignored by the fold, exactly like a TEST/unknown no-op). */
  corrupt: boolean;
}

interface TransferSpec {
  kind: 'transfer';
  from: string;
  to: string;
  ts: number;
}

type Spec = LifecycleSpec | TransferSpec;

const lifecycleArb: fc.Arbitrary<Spec> = fc.record({
  kind: fc.constant<'lifecycle'>('lifecycle'),
  uid: fc.constantFrom(...UIDS),
  ts: fc.integer({ min: 1, max: 3 }), // colliding on purpose
  type: fc.constantFrom(
    'INITIAL_PURCHASE',
    'RENEWAL',
    'NON_RENEWING_PURCHASE',
    'PRODUCT_CHANGE',
    'UNCANCELLATION',
    'CANCELLATION',
    'BILLING_ISSUE',
    'SUBSCRIPTION_PAUSED',
    'SUBSCRIPTION_EXTENDED',
    'EXPIRATION',
    'TEST',
    'INVOICE_ISSUED',
  ),
  product: fc.constantFrom('premium.monthly', 'premium.yearly', null),
  newProduct: fc.constantFrom('premium.monthly', null),
  exp: fc.option(fc.integer({ min: 0, max: 100_000 }), { nil: null }),
  grace: fc.option(fc.integer({ min: 0, max: 100_000 }), { nil: null }),
  entitlementIds: fc.constantFrom(['premium'], ['premium', 'coach'], null),
  corrupt: fc.boolean(),
});

/** Transfers are drawn across the SAME uid pool, so both the within-couple
 *  (hold) and cross-couple (revoke) shapes are generated. */
const transferArb: fc.Arbitrary<Spec> = fc.record({
  kind: fc.constant<'transfer'>('transfer'),
  from: fc.constantFrom(...UIDS),
  to: fc.constantFrom(...UIDS),
  ts: fc.integer({ min: 1, max: 3 }),
});

const specArb: fc.Arbitrary<Spec> = fc.oneof(
  { weight: 3, arbitrary: lifecycleArb },
  { weight: 1, arbitrary: transferArb },
);

/** Materializes a spec into an RcEvent with a GLOBALLY UNIQUE id (evt-<index>),
 *  so a duplicated event object is a true replay (same id ⇒ same payload). */
function toEvent(spec: Spec, index: number): RcEvent {
  const base = {
    id: `evt-${index}`,
    eventTimestampMs: spec.ts,
    originalAppUserId: null,
    aliases: [],
    environment: 'PRODUCTION',
    store: 'APP_STORE',
    newProductId: null,
    periodType: 'NORMAL',
    gracePeriodExpirationAtMs: null,
    entitlementIds: null,
    transferredFrom: null,
    transferredTo: null,
  };
  if (spec.kind === 'transfer') {
    return {
      ...base,
      type: 'TRANSFER',
      appUserId: null,
      productId: null,
      expirationAtMs: undefined,
      transferredFrom: [spec.from],
      transferredTo: [spec.to],
    };
  }
  return {
    ...base,
    type: spec.type,
    appUserId: spec.uid,
    productId: spec.product,
    newProductId: spec.newProduct,
    // A corrupt projecting event carries a non-numeric expiration → unprojectable.
    expirationAtMs: spec.corrupt ? 'not-a-number' : spec.exp,
    gracePeriodExpirationAtMs: spec.grace,
    entitlementIds: spec.entitlementIds,
  };
}

/** The mirror of the whole (two-couple) world: coupleId → lanes. */
type World = Record<string, Record<string, Lane>>;

/** The service's identity resolution, as a pure lookup over the static world. */
function resolve(id: string): TransferResolution {
  const coupleId = WORLD[id];
  return coupleId === undefined ? { id, status: 'unknown' } : { id, status: 'couple', coupleId };
}

/**
 * Folds ONE event through the same pure primitives the service uses. A lifecycle
 * event touches its author's couple; a transfer runs the gate → resolve → plan
 * pipeline and tombstones each target lane on its own couple.
 */
function step(world: World, event: RcEvent): World {
  if (event.type === 'TRANSFER') {
    const gate = gateTransfer(event);
    if (gate.kind !== 'resolve') {
      return world;
    }
    const plan = planTransfer(gate.fromIds.map(resolve), gate.toIds.map(resolve));
    if (plan.kind !== 'revoke') {
      return world;
    }
    let next = world;
    for (const target of plan.targets) {
      const lanes = next[target.coupleId] ?? {};
      const nextLanes = revokeLane(lanes, target.uid, event, 0);
      if (nextLanes !== lanes) {
        next = { ...next, [target.coupleId]: nextLanes };
      }
    }
    return next;
  }

  const uid = event.appUserId;
  if (uid === null) {
    return world;
  }
  const coupleId = WORLD[uid];
  const lanes = world[coupleId] ?? {};
  const nextLanes = applyLane(lanes, uid, event, 0);
  return nextLanes === lanes ? world : { ...world, [coupleId]: nextLanes };
}

interface Reduced {
  lanes: World;
  summaries: Record<string, EntitlementSummary>;
}

function reduce(events: RcEvent[]): Reduced {
  let lanes: World = {};
  for (const event of events) {
    lanes = step(lanes, event);
  }
  const summaries: Record<string, EntitlementSummary> = {};
  for (const coupleId of COUPLES) {
    if (lanes[coupleId] !== undefined) {
      summaries[coupleId] = deriveSummary(lanes[coupleId]);
    }
  }
  return { lanes, summaries };
}

/** Ascending total order (ts, id) — the "clean in-order delivery" oracle. */
function byOrder(a: RcEvent, b: RcEvent): number {
  if (a.eventTimestampMs !== b.eventTimestampMs) {
    return a.eventTimestampMs - b.eventTimestampMs;
  }
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

/** A deterministic permutation of `bag` driven by fc-supplied keys. */
function permute(bag: RcEvent[], keys: number[]): RcEvent[] {
  return bag
    .map((event, index) => ({ event, index, key: keys.length ? keys[index % keys.length] : index }))
    .sort((a, b) => (a.key !== b.key ? a.key - b.key : a.index - b.index))
    .map((entry) => entry.event);
}

/**
 * Does this event WRITE the given uid's lane (on that uid's couple)? A lifecycle
 * event does iff it projects for that author; a TRANSFER does iff the plan makes
 * that uid a revoke target. This is the independent oracle for "which event won
 * a lane" — deliberately re-derived from the plan, not from the fold.
 */
function writesLane(event: RcEvent, uid: string): boolean {
  if (event.type === 'TRANSFER') {
    const gate = gateTransfer(event);
    if (gate.kind !== 'resolve') return false;
    const plan = planTransfer(gate.fromIds.map(resolve), gate.toIds.map(resolve));
    return plan.kind === 'revoke' && plan.targets.some((target) => target.uid === uid);
  }
  return event.appUserId === uid && projectEvent(event).kind === 'project';
}

describe('entitlement mirror converges under any permutation + duplication', () => {
  it('two random arrangements of the same event multiset land on identical lanes + summaries (two couples, transfers mixed in)', () => {
    fc.assert(
      fc.property(
        fc.array(specArb, { maxLength: 16 }),
        fc.array(fc.nat(), { maxLength: 12 }), // which events to duplicate
        fc.array(fc.integer(), { maxLength: 32 }), // permutation keys, arrangement 1
        fc.array(fc.integer(), { maxLength: 32 }), // permutation keys, arrangement 2
        (specs, dupPicks, keys1, keys2) => {
          const events = specs.map(toEvent);
          // The multiset support is `events`; add whole-event duplicates (replays).
          const dups = events.length === 0 ? [] : dupPicks.map((p) => events[p % events.length]);
          const bag = [...events, ...dups];

          const arrangement1 = reduce(permute(bag, keys1));
          const arrangement2 = reduce(permute(bag, keys2));

          // Order + duplication independence: the two arrangements are identical,
          // on BOTH couple docs.
          expect(arrangement1).toEqual(arrangement2);
          // And both equal clean in-order delivery of the base set (no dups).
          expect(arrangement1).toEqual(reduce([...events].sort(byOrder)));

          // Independent oracle for the WINNER: each lane holds the projection of
          // the max-(ts, id) event that WRITES it (lifecycle projection or
          // transfer tombstone); a uid no event writes never gets a lane.
          for (const uid of UIDS) {
            const writers = events.filter((event) => writesLane(event, uid)).sort(byOrder);
            const lane = arrangement1.lanes[WORLD[uid]]?.[uid];
            if (writers.length === 0) {
              expect(lane).toBeUndefined();
            } else {
              const winner = writers[writers.length - 1];
              expect(lane.lastEventId).toBe(winner.id);
              expect(lane.lastEventTimestampMs).toBe(winner.eventTimestampMs);
              // The tombstone/lifecycle split is itself pinned: a transfer-won
              // lane is ALWAYS un-entitled (a transfer never grants), and its
              // expiry is the transfer instant — never the non-expiring sentinel.
              if (winner.type === 'TRANSFER') {
                expect(lane.entitled).toBe(false);
                expect(lane.expiresAtMs).toBe(winner.eventTimestampMs);
              }
            }
          }

          // THE invariant (ADR-015 Decision 1): a TRANSFER never creates or
          // entitles a GAINER's lane. Every entitled lane in the world traces to
          // a lifecycle event for that very uid.
          for (const coupleId of COUPLES) {
            for (const [uid, lane] of Object.entries(arrangement1.lanes[coupleId] ?? {})) {
              if (lane.entitled) {
                expect(
                  events.some(
                    (event) =>
                      event.type !== 'TRANSFER' &&
                      event.appUserId === uid &&
                      projectEvent(event).kind === 'project',
                  ),
                ).toBe(true);
              }
            }
          }
        },
      ),
    );
  });
});
