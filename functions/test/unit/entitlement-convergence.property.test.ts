// M4.1 convergence property (ADR-013 Decision 4) — the entitlement analog of
// the M3.4 streak property test. RC gives NO cross-event ordering guarantee and
// re-delivers events (retries reuse the same id + payload), so the mirror MUST
// converge: any permutation + duplication of an event set has to land on the
// projection of the total-order-maximal event per uid. The generator
// DELIBERATELY draws colliding timestamps (a 1..3 range) so equal-ts distinct
// events — same-millisecond store bursts — are the common case, forcing the
// (ts, id) tie-break to carry the determinism.
import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

import {
  EntitlementSummary,
  Lane,
  RcEvent,
  applyLane,
  deriveSummary,
  projectEvent,
} from '../../src/entitlements/entitlement-core';

interface Spec {
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

const specArb: fc.Arbitrary<Spec> = fc.record({
  uid: fc.constantFrom('uid-a', 'uid-b', 'uid-c'),
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
    'TRANSFER',
  ),
  product: fc.constantFrom('premium.monthly', 'premium.yearly', null),
  newProduct: fc.constantFrom('premium.monthly', null),
  exp: fc.option(fc.integer({ min: 0, max: 100_000 }), { nil: null }),
  grace: fc.option(fc.integer({ min: 0, max: 100_000 }), { nil: null }),
  entitlementIds: fc.constantFrom(['premium'], ['premium', 'coach'], null),
  corrupt: fc.boolean(),
});

/** Materializes a spec into an RcEvent with a GLOBALLY UNIQUE id (evt-<index>),
 *  so a duplicated event object is a true replay (same id ⇒ same payload). */
function toEvent(spec: Spec, index: number): RcEvent {
  return {
    type: spec.type,
    id: `evt-${index}`,
    eventTimestampMs: spec.ts,
    appUserId: spec.uid,
    originalAppUserId: null,
    aliases: [],
    environment: 'PRODUCTION',
    store: 'APP_STORE',
    productId: spec.product,
    newProductId: spec.newProduct,
    periodType: 'NORMAL',
    // A corrupt projecting event carries a non-numeric expiration → unprojectable.
    expirationAtMs: spec.corrupt ? 'not-a-number' : spec.exp,
    gracePeriodExpirationAtMs: spec.grace,
    entitlementIds: spec.entitlementIds,
  };
}

interface Reduced {
  lanes: Record<string, Lane>;
  summary: EntitlementSummary;
}

/** Folds a delivery sequence through the pure guard+projection (updatedAtMs=0 so
 *  it never perturbs equality), then derives the couple summary. */
function reduce(events: RcEvent[]): Reduced {
  let lanes: Record<string, Lane> = {};
  for (const event of events) {
    lanes = applyLane(lanes, event.appUserId, event, 0);
  }
  return { lanes, summary: deriveSummary(lanes) };
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

describe('entitlement mirror converges under any permutation + duplication', () => {
  it('two random arrangements of the same event multiset land on identical lanes + summary', () => {
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

          // Order + duplication independence: the two arrangements are identical.
          expect(arrangement1).toEqual(arrangement2);
          // And both equal clean in-order delivery of the base set (no dups).
          expect(arrangement1).toEqual(reduce([...events].sort(byOrder)));

          // Independent oracle for the WINNER: each lane holds the projection of
          // the max-(ts, id) PROJECTING event for that uid; a uid with only
          // no-op/unprojectable events never gets a lane.
          for (const uid of ['uid-a', 'uid-b', 'uid-c']) {
            const projecting = events
              .filter((e) => e.appUserId === uid && projectEvent(e).kind === 'project')
              .sort(byOrder);
            const lane = arrangement1.lanes[uid];
            if (projecting.length === 0) {
              expect(lane).toBeUndefined();
            } else {
              const winner = projecting[projecting.length - 1];
              expect(lane.lastEventId).toBe(winner.id);
              expect(lane.lastEventTimestampMs).toBe(winner.eventTimestampMs);
            }
          }
        },
      ),
    );
  });
});
