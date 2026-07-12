// Pure-core unit tests (no emulator) for the RevenueCat mirror decision logic
// (M4.1, ADR-013): envelope parsing, the Decision-2 projection table for EVERY
// event type, the total-order guard, the summary tie-break, and the PII-safe log
// projection. Branch coverage lives here (vitest.config include: src/**).
import { describe, expect, it } from 'vitest';

import {
  FREE_SUMMARY,
  Lane,
  MAX_TRANSFER_IDS,
  RC_ANONYMOUS_PREFIX,
  RcEvent,
  TransferResolution,
  applyLane,
  decide,
  deriveSummary,
  gateTransfer,
  logProjection,
  parseRcEvent,
  planTransfer,
  projectEvent,
  revokeLane,
  revokedLane,
} from '../../src/entitlements/entitlement-core';

// A valid parsed event; overrides replace individual fields per case.
function rcEvent(overrides: Partial<RcEvent> = {}): RcEvent {
  return {
    type: 'INITIAL_PURCHASE',
    id: 'evt-1',
    eventTimestampMs: 1_000,
    appUserId: 'uid-a',
    originalAppUserId: null,
    aliases: [],
    environment: 'PRODUCTION',
    store: 'APP_STORE',
    productId: 'premium.monthly',
    newProductId: null,
    periodType: 'NORMAL',
    expirationAtMs: 9_000,
    gracePeriodExpirationAtMs: null,
    entitlementIds: ['premium'],
    transferredFrom: null,
    transferredTo: null,
    ...overrides,
  };
}

/** A parsed TRANSFER event (ADR-015): NO appUserId, transfer arrays instead. */
function transferEvent(overrides: Partial<RcEvent> = {}): RcEvent {
  return rcEvent({
    type: 'TRANSFER',
    id: 'evt-t1',
    eventTimestampMs: 5_000,
    appUserId: null,
    productId: null,
    periodType: null,
    expirationAtMs: undefined,
    entitlementIds: null,
    transferredFrom: ['uid-a'],
    transferredTo: ['uid-b'],
    ...overrides,
  });
}

const ANON = `${RC_ANONYMOUS_PREFIX}deadbeef`;

/** Resolution shorthands for the planTransfer table. */
const inCouple = (id: string, coupleId: string): TransferResolution => ({ id, status: 'couple', coupleId });
const unpaired = (id: string): TransferResolution => ({ id, status: 'unpaired' });
const unknown = (id: string): TransferResolution => ({ id, status: 'unknown' });

// A full stored lane; overrides replace fields for the summary/guard tests.
function lane(overrides: Partial<Lane> = {}): Lane {
  return {
    entitled: true,
    productId: 'premium.monthly',
    periodType: 'NORMAL',
    expiresAtMs: 9_000,
    willRenew: true,
    store: 'APP_STORE',
    environment: 'PRODUCTION',
    entitlementIds: ['premium'],
    lastEventId: 'evt-1',
    lastEventTimestampMs: 1_000,
    updatedAtMs: 0,
    ...overrides,
  };
}

// A raw RC webhook envelope for parseRcEvent; `event` overrides merge into the
// documented field set.
function rawBody(event: Record<string, unknown> = {}): unknown {
  return {
    api_version: '1.0',
    event: {
      type: 'INITIAL_PURCHASE',
      id: 'evt-1',
      event_timestamp_ms: 1_000,
      app_user_id: 'uid-a',
      ...event,
    },
  };
}

describe('parseRcEvent — envelope contract', () => {
  it('maps the documented field set (snake_case → camelCase) on a full envelope', () => {
    const result = parseRcEvent({
      api_version: '1.0',
      event: {
        type: 'RENEWAL',
        id: 'evt-9',
        event_timestamp_ms: 42,
        app_user_id: 'uid-a',
        original_app_user_id: 'orig-a',
        aliases: ['alias-1', 'alias-2'],
        environment: 'SANDBOX',
        store: 'PLAY_STORE',
        product_id: 'premium.yearly',
        new_product_id: 'premium.monthly',
        period_type: 'TRIAL',
        expiration_at_ms: 99,
        grace_period_expiration_at_ms: 55,
        entitlement_ids: ['premium'],
      },
    });
    expect(result).toEqual({
      status: 'ok',
      event: {
        type: 'RENEWAL',
        id: 'evt-9',
        eventTimestampMs: 42,
        appUserId: 'uid-a',
        originalAppUserId: 'orig-a',
        aliases: ['alias-1', 'alias-2'],
        environment: 'SANDBOX',
        store: 'PLAY_STORE',
        productId: 'premium.yearly',
        newProductId: 'premium.monthly',
        periodType: 'TRIAL',
        expirationAtMs: 99,
        gracePeriodExpirationAtMs: 55,
        entitlementIds: ['premium'],
        transferredFrom: null,
        transferredTo: null,
      },
    });
  });

  it('defaults absent optionals: null strings, empty aliases, null entitlementIds', () => {
    const result = parseRcEvent(rawBody());
    expect(result.status).toBe('ok');
    if (result.status !== 'ok') return;
    expect(result.event.originalAppUserId).toBeNull();
    expect(result.event.aliases).toEqual([]);
    expect(result.event.environment).toBeNull();
    expect(result.event.store).toBeNull();
    expect(result.event.productId).toBeNull();
    expect(result.event.newProductId).toBeNull();
    expect(result.event.periodType).toBeNull();
    expect(result.event.entitlementIds).toBeNull();
    // TRANSFER-only fields, absent on a lifecycle event.
    expect(result.event.transferredFrom).toBeNull();
    expect(result.event.transferredTo).toBeNull();
    // The two entitled-until candidates are passed through untouched (absent).
    expect(result.event.expirationAtMs).toBeUndefined();
    expect(result.event.gracePeriodExpirationAtMs).toBeUndefined();
  });

  it("coerces empty-string display fields to null and filters non-string aliases", () => {
    const result = parseRcEvent(
      rawBody({ environment: '', product_id: '', aliases: ['ok', 42, null], entitlement_ids: ['premium', 7] }),
    );
    expect(result.status).toBe('ok');
    if (result.status !== 'ok') return;
    expect(result.event.environment).toBeNull();
    expect(result.event.productId).toBeNull();
    expect(result.event.aliases).toEqual(['ok']);
    expect(result.event.entitlementIds).toEqual(['premium']);
  });

  it.each([
    ['body not an object (null)', null],
    ['body not an object (string)', 'nope'],
    ['body not an object (array)', []],
  ])('rejects %s as malformed', (_label, body) => {
    expect(parseRcEvent(body)).toEqual({ status: 'malformed' });
  });

  it.each([
    ['no event object', { api_version: '1.0' }],
    ['event is null', { event: null }],
    ['event is an array', { event: [] }],
    ['type missing', rawBody({ type: undefined })],
    ['type not a string', rawBody({ type: 5 })],
    ['type empty', rawBody({ type: '' })],
    ['id missing', rawBody({ id: undefined })],
    ['id not a string', rawBody({ id: {} })],
    ['id empty', rawBody({ id: '' })],
    ['event_timestamp_ms missing', rawBody({ event_timestamp_ms: undefined })],
    ['event_timestamp_ms not a number', rawBody({ event_timestamp_ms: '1000' })],
    ['event_timestamp_ms NaN', rawBody({ event_timestamp_ms: Number.NaN })],
    ['event_timestamp_ms Infinity', rawBody({ event_timestamp_ms: Number.POSITIVE_INFINITY })],
    ['app_user_id missing', rawBody({ app_user_id: undefined })],
    ['app_user_id not a string', rawBody({ app_user_id: 123 })],
    ['app_user_id empty', rawBody({ app_user_id: '' })],
  ])('rejects %s as malformed', (_label, body) => {
    expect(parseRcEvent(body)).toEqual({ status: 'malformed' });
  });
});

describe('projectEvent — Decision 2 table, every type', () => {
  it('INITIAL_PURCHASE: entitled, willRenew true, entitled-until = expiration', () => {
    const projection = projectEvent(rcEvent({ type: 'INITIAL_PURCHASE', expirationAtMs: 9_000 }));
    expect(projection).toEqual({
      kind: 'project',
      lane: {
        entitled: true,
        productId: 'premium.monthly',
        periodType: 'NORMAL',
        expiresAtMs: 9_000,
        willRenew: true,
        store: 'APP_STORE',
        environment: 'PRODUCTION',
        entitlementIds: ['premium'],
      },
    });
  });

  it('INITIAL_PURCHASE with null expiration → non-expiring (expiresAtMs null)', () => {
    const projection = projectEvent(rcEvent({ expirationAtMs: null }));
    expect(projection).toMatchObject({ kind: 'project', lane: { entitled: true, expiresAtMs: null } });
  });

  it('RENEWAL: entitled, willRenew true', () => {
    expect(projectEvent(rcEvent({ type: 'RENEWAL' }))).toMatchObject({
      kind: 'project',
      lane: { entitled: true, willRenew: true },
    });
  });

  it('NON_RENEWING_PURCHASE: entitled but willRenew FALSE', () => {
    expect(projectEvent(rcEvent({ type: 'NON_RENEWING_PURCHASE' }))).toMatchObject({
      kind: 'project',
      lane: { entitled: true, willRenew: false },
    });
  });

  it('PRODUCT_CHANGE with new_product_id → product = new_product_id, willRenew true', () => {
    expect(
      projectEvent(rcEvent({ type: 'PRODUCT_CHANGE', productId: 'old.plan', newProductId: 'new.plan' })),
    ).toMatchObject({ kind: 'project', lane: { productId: 'new.plan', willRenew: true } });
  });

  it('PRODUCT_CHANGE without new_product_id → falls back to the (old) product_id', () => {
    expect(
      projectEvent(rcEvent({ type: 'PRODUCT_CHANGE', productId: 'old.plan', newProductId: null })),
    ).toMatchObject({ kind: 'project', lane: { productId: 'old.plan' } });
  });

  it('UNCANCELLATION: entitled, willRenew true', () => {
    expect(projectEvent(rcEvent({ type: 'UNCANCELLATION' }))).toMatchObject({
      kind: 'project',
      lane: { entitled: true, willRenew: true },
    });
  });

  it('CANCELLATION: STILL entitled (access kept), willRenew false', () => {
    expect(projectEvent(rcEvent({ type: 'CANCELLATION' }))).toMatchObject({
      kind: 'project',
      lane: { entitled: true, willRenew: false },
    });
  });

  it('BILLING_ISSUE with a grace period → entitled-until = grace, willRenew true', () => {
    expect(
      projectEvent(
        rcEvent({ type: 'BILLING_ISSUE', gracePeriodExpirationAtMs: 12_000, expirationAtMs: 9_000 }),
      ),
    ).toMatchObject({ kind: 'project', lane: { entitled: true, willRenew: true, expiresAtMs: 12_000 } });
  });

  it('BILLING_ISSUE with NULL grace falls back to expiration — never the non-expiring sentinel', () => {
    // The review's blocking finding: a null grace must NOT collapse to null
    // (non-expiring), which would mint permanent free premium on a failed card.
    const projection = projectEvent(
      rcEvent({ type: 'BILLING_ISSUE', gracePeriodExpirationAtMs: null, expirationAtMs: 9_000 }),
    );
    expect(projection).toMatchObject({ kind: 'project', lane: { entitled: true, expiresAtMs: 9_000 } });
    // Explicit: the fallback is the expiration, NOT null.
    if (projection.kind === 'project') {
      expect(projection.lane.expiresAtMs).not.toBeNull();
    }
  });

  it('BILLING_ISSUE with null grace AND null expiration → non-expiring (both truly null)', () => {
    expect(
      projectEvent(rcEvent({ type: 'BILLING_ISSUE', gracePeriodExpirationAtMs: null, expirationAtMs: null })),
    ).toMatchObject({ kind: 'project', lane: { entitled: true, expiresAtMs: null } });
  });

  it('SUBSCRIPTION_PAUSED: entitled, willRenew false', () => {
    expect(projectEvent(rcEvent({ type: 'SUBSCRIPTION_PAUSED' }))).toMatchObject({
      kind: 'project',
      lane: { entitled: true, willRenew: false },
    });
  });

  it('SUBSCRIPTION_EXTENDED: entitled, willRenew true, entitled-until = new expiration', () => {
    expect(
      projectEvent(rcEvent({ type: 'SUBSCRIPTION_EXTENDED', expirationAtMs: 20_000 })),
    ).toMatchObject({ kind: 'project', lane: { entitled: true, willRenew: true, expiresAtMs: 20_000 } });
  });

  it('EXPIRATION: the ONLY revoking event — entitled false, willRenew false', () => {
    expect(projectEvent(rcEvent({ type: 'EXPIRATION', expirationAtMs: 500 }))).toMatchObject({
      kind: 'project',
      lane: { entitled: false, willRenew: false, expiresAtMs: 500 },
    });
  });

  it('TEST: logged no-op (never persisted)', () => {
    expect(projectEvent(rcEvent({ type: 'TEST' }))).toEqual({ kind: 'noop' });
  });

  it.each(['INVOICE_ISSUED', 'SOME_FUTURE_TYPE'])(
    'unknown type %s: logged no-op (never a retry loop)',
    (type) => {
      expect(projectEvent(rcEvent({ type }))).toEqual({ kind: 'noop' });
    },
  );

  // ADR-015: TRANSFER is NOT a lifecycle projection — the transfer path owns it.
  // Keeping it out of PROJECTING_WILL_RENEW is what guarantees the LIFECYCLE
  // projection can never mint an entitled lane from an event that carries no
  // product and no expiry (Decision 1).
  it('TRANSFER never projects a lifecycle lane (the transfer path owns it)', () => {
    expect(projectEvent(transferEvent())).toEqual({ kind: 'noop' });
  });

  it('carries entitlementIds through to the lane verbatim', () => {
    const projection = projectEvent(rcEvent({ entitlementIds: ['premium', 'coach'] }));
    expect(projection).toMatchObject({ kind: 'project', lane: { entitlementIds: ['premium', 'coach'] } });
  });

  it('known type with a non-numeric expiration → unprojectable (no mutate on doubt)', () => {
    expect(projectEvent(rcEvent({ expirationAtMs: 'soon' }))).toEqual({ kind: 'unprojectable' });
  });

  it('BILLING_ISSUE with a non-numeric grace → unprojectable', () => {
    expect(
      projectEvent(rcEvent({ type: 'BILLING_ISSUE', gracePeriodExpirationAtMs: 'later' })),
    ).toEqual({ kind: 'unprojectable' });
  });

  it('BILLING_ISSUE with null grace + non-numeric expiration → unprojectable', () => {
    expect(
      projectEvent(
        rcEvent({ type: 'BILLING_ISSUE', gracePeriodExpirationAtMs: null, expirationAtMs: {} }),
      ),
    ).toEqual({ kind: 'unprojectable' });
  });
});

describe('decide — total-order guard (event_timestamp_ms, id)', () => {
  const base = rcEvent({ eventTimestampMs: 100, id: 'm' });

  it('applies against an absent lane', () => {
    expect(decide(null, base)).toBe('apply');
  });

  it('replay-skips an identical (ts, id)', () => {
    expect(decide({ lastEventTimestampMs: 100, lastEventId: 'm' }, base)).toBe('replay-skip');
  });

  it('applies a strictly newer timestamp', () => {
    expect(decide({ lastEventTimestampMs: 99, lastEventId: 'zzz' }, base)).toBe('apply');
  });

  it('stale-skips a strictly older timestamp', () => {
    expect(decide({ lastEventTimestampMs: 101, lastEventId: 'a' }, base)).toBe('stale-skip');
  });

  it('equal ts, larger id → apply', () => {
    expect(decide({ lastEventTimestampMs: 100, lastEventId: 'l' }, base)).toBe('apply');
  });

  it('equal ts, smaller id → stale-skip', () => {
    expect(decide({ lastEventTimestampMs: 100, lastEventId: 'n' }, base)).toBe('stale-skip');
  });
});

describe('deriveSummary — Decision 4 tie-break', () => {
  it('empty lanes → the free zero-state', () => {
    expect(deriveSummary({})).toEqual(FREE_SUMMARY);
  });

  it('a single entitled lane surfaces its display fields', () => {
    expect(deriveSummary({ a: lane({ productId: 'premium.monthly', expiresAtMs: 9_000 }) })).toEqual({
      entitled: true,
      productId: 'premium.monthly',
      periodType: 'NORMAL',
      expiresAtMs: 9_000,
      willRenew: true,
      store: 'APP_STORE',
      environment: 'PRODUCTION',
    });
  });

  it('a single non-entitled lane → entitled false', () => {
    expect(deriveSummary({ a: lane({ entitled: false }) }).entitled).toBe(false);
  });

  it('any entitled lane makes the couple entitled (one purchase entitles both)', () => {
    const summary = deriveSummary({
      a: lane({ entitled: false, productId: 'old', expiresAtMs: 1 }),
      b: lane({ entitled: true, productId: 'premium.monthly', expiresAtMs: 9_000 }),
    });
    expect(summary.entitled).toBe(true);
    expect(summary.productId).toBe('premium.monthly'); // winner is the entitled lane
  });

  it('among entitled lanes, the later expiry wins the display fields', () => {
    const summary = deriveSummary({
      a: lane({ productId: 'earlier', expiresAtMs: 5_000 }),
      b: lane({ productId: 'later', expiresAtMs: 9_000 }),
    });
    expect(summary.productId).toBe('later');
    expect(summary.expiresAtMs).toBe(9_000);
  });

  it('a non-expiring (null) entitled lane ranks above any dated one', () => {
    const summary = deriveSummary({
      a: lane({ productId: 'dated', expiresAtMs: 9_999_999 }),
      b: lane({ productId: 'forever', expiresAtMs: null }),
    });
    expect(summary.productId).toBe('forever');
    expect(summary.expiresAtMs).toBeNull();
  });

  it('equal entitled + expiry → the larger (ts, id) order key breaks the tie', () => {
    const summary = deriveSummary({
      a: lane({ productId: 'older', expiresAtMs: 9_000, lastEventTimestampMs: 100, lastEventId: 'a' }),
      b: lane({ productId: 'newer', expiresAtMs: 9_000, lastEventTimestampMs: 200, lastEventId: 'a' }),
    });
    expect(summary.productId).toBe('newer');
  });

  it('equal entitled + expiry + ts → the larger id breaks the tie deterministically', () => {
    const summary = deriveSummary({
      a: lane({ productId: 'id-a', expiresAtMs: 9_000, lastEventTimestampMs: 100, lastEventId: 'a' }),
      b: lane({ productId: 'id-b', expiresAtMs: 9_000, lastEventTimestampMs: 100, lastEventId: 'b' }),
    });
    expect(summary.productId).toBe('id-b');
  });
});

describe('applyLane — pure guard + projection fold', () => {
  it('adds a lane (with order key + updatedAtMs) to an empty map', () => {
    const next = applyLane({}, 'uid-a', rcEvent({ id: 'evt-1', eventTimestampMs: 5 }), 777);
    expect(next['uid-a']).toMatchObject({
      entitled: true,
      lastEventId: 'evt-1',
      lastEventTimestampMs: 5,
      updatedAtMs: 777,
    });
  });

  it('returns the SAME reference for a no-op type (no change)', () => {
    const lanes = { 'uid-a': lane() };
    expect(applyLane(lanes, 'uid-a', rcEvent({ type: 'TEST' }), 1)).toBe(lanes);
  });

  it('returns the SAME reference for an unprojectable event', () => {
    const lanes = { 'uid-a': lane() };
    expect(applyLane(lanes, 'uid-a', rcEvent({ expirationAtMs: 'nope' }), 1)).toBe(lanes);
  });

  it('returns the SAME reference for a replayed (equal-order) event', () => {
    const lanes = { 'uid-a': lane({ lastEventId: 'evt-1', lastEventTimestampMs: 5 }) };
    expect(applyLane(lanes, 'uid-a', rcEvent({ id: 'evt-1', eventTimestampMs: 5 }), 1)).toBe(lanes);
  });

  it('returns the SAME reference for a stale (older-order) event', () => {
    const lanes = { 'uid-a': lane({ lastEventId: 'z', lastEventTimestampMs: 500 }) };
    expect(applyLane(lanes, 'uid-a', rcEvent({ id: 'a', eventTimestampMs: 100 }), 1)).toBe(lanes);
  });

  it('advances the lane for a strictly newer event, leaving siblings untouched', () => {
    const sibling = lane({ lastEventId: 'sib', lastEventTimestampMs: 1 });
    const lanes = { 'uid-a': lane({ lastEventId: 'old', lastEventTimestampMs: 5 }), 'uid-b': sibling };
    const next = applyLane(lanes, 'uid-a', rcEvent({ type: 'EXPIRATION', id: 'new', eventTimestampMs: 50, expirationAtMs: 60 }), 9);
    expect(next).not.toBe(lanes);
    expect(next['uid-a']).toMatchObject({ entitled: false, lastEventId: 'new', lastEventTimestampMs: 50 });
    expect(next['uid-b']).toBe(sibling); // sibling lane object preserved by reference
  });
});

describe('logProjection — PII-safe surface', () => {
  it('carries only {type, id, environment, decision} without a coupleId', () => {
    const fields = logProjection(rcEvent({ type: 'RENEWAL', id: 'evt-7', environment: 'SANDBOX' }), 'applied');
    expect(fields).toEqual({ type: 'RENEWAL', id: 'evt-7', environment: 'SANDBOX', decision: 'applied' });
  });

  it('adds coupleId only when provided', () => {
    const fields = logProjection(rcEvent(), 'applied', 'couple-1');
    expect(Object.keys(fields).sort()).toEqual(['coupleId', 'decision', 'environment', 'id', 'type']);
  });

  it('never leaks the raw body, subscriber_attributes, or aliases', () => {
    const fields = logProjection(rcEvent({ aliases: ['secret-alias'] }), 'unresolvable', 'couple-1');
    const serialized = JSON.stringify(fields);
    expect(serialized).not.toContain('secret-alias');
    expect(serialized).not.toContain('subscriber_attributes');
  });
});

// --- TRANSFER (ADR-015) ------------------------------------------------------

describe('parseRcEvent — the TRANSFER envelope (ADR-015 Finding 0)', () => {
  // THE regression: RC's real transfer body carries NO app_user_id. Before
  // ADR-015 this parsed as `malformed` → 400 → RC burned its 5-retry budget and
  // dropped the event. Body shape verbatim from RC's documented sample.
  it('accepts a real TRANSFER body with NO app_user_id', () => {
    const result = parseRcEvent({
      api_version: '1.0',
      event: {
        type: 'TRANSFER',
        id: 'CD489E0E-5D52-4E03-966B-A7F17788E432',
        event_timestamp_ms: 78_789_789_798_798,
        store: 'APP_STORE',
        environment: 'PRODUCTION',
        transferred_from: ['00005A1C-6091-4F81-BE77-F0A83A271AB6'],
        transferred_to: ['4BEDB450-8EF2-11E9-B475-0800200C9A66'],
      },
    });

    expect(result.status).toBe('ok');
    if (result.status !== 'ok') return;
    expect(result.event.appUserId).toBeNull();
    expect(result.event.transferredFrom).toEqual(['00005A1C-6091-4F81-BE77-F0A83A271AB6']);
    expect(result.event.transferredTo).toEqual(['4BEDB450-8EF2-11E9-B475-0800200C9A66']);
  });

  // The exception is exactly ONE type wide. Goes red if someone "fixes" the
  // above by making app_user_id optional for every type.
  it('a LIFECYCLE event without app_user_id is STILL malformed (per-type contract)', () => {
    const result = parseRcEvent({
      api_version: '1.0',
      event: { type: 'INITIAL_PURCHASE', id: 'evt-1', event_timestamp_ms: 1_000 },
    });
    expect(result).toEqual({ status: 'malformed' });
  });

  it('a TRANSFER whose transfer arrays are absent or non-arrays maps them to null', () => {
    const result = parseRcEvent(
      rawBody({ type: 'TRANSFER', app_user_id: undefined, transferred_from: 'not-an-array' }),
    );
    expect(result.status).toBe('ok');
    if (result.status !== 'ok') return;
    expect(result.event.transferredFrom).toBeNull();
    expect(result.event.transferredTo).toBeNull();
  });
});

describe('gateTransfer — the pre-read gate (ADR-015 Decision 3)', () => {
  it('resolves a clean transfer: the surviving ids, deduped', () => {
    const gate = gateTransfer(
      transferEvent({ transferredFrom: ['uid-a', 'uid-a'], transferredTo: ['uid-b'] }),
    );
    expect(gate).toEqual({ kind: 'resolve', fromIds: ['uid-a'], toIds: ['uid-b'] });
  });

  it.each([
    ['transferred_from absent', { transferredFrom: null }],
    ['transferred_to absent', { transferredTo: null }],
  ])('%s → unprojectable (per-type schema drift, a 200 skip — never a 400)', (_label, overrides) => {
    expect(gateTransfer(transferEvent(overrides))).toEqual({ kind: 'unprojectable' });
  });

  // THE reinstall false-downgrade regression. An anon id in `to` may be the
  // LOSER THEMSELVES mid-reinstall; filtering it away and calling the rest
  // "fully known" would strip premium from a paying couple. Goes red if someone
  // "symmetrizes" the anon filter across both arrays.
  it('an anon id ANYWHERE in transferred_to holds (never revokes)', () => {
    expect(gateTransfer(transferEvent({ transferredTo: [ANON, 'uid-b'] }))).toEqual({
      kind: 'hold',
      reason: 'ambiguous-destination',
    });
  });

  it('an anon-ONLY destination holds', () => {
    expect(gateTransfer(transferEvent({ transferredTo: [ANON] }))).toEqual({
      kind: 'hold',
      reason: 'ambiguous-destination',
    });
  });

  it('an empty destination holds', () => {
    expect(gateTransfer(transferEvent({ transferredTo: [] }))).toEqual({
      kind: 'hold',
      reason: 'ambiguous-destination',
    });
  });

  it('anon ids in transferred_from are FILTERED (they are never a Firebase uid)', () => {
    const gate = gateTransfer(transferEvent({ transferredFrom: [ANON, 'uid-a'] }));
    expect(gate).toEqual({ kind: 'resolve', fromIds: ['uid-a'], toIds: ['uid-b'] });
  });

  it('a from-side left empty by the anon filter holds as no-loser (zero reads)', () => {
    expect(gateTransfer(transferEvent({ transferredFrom: [ANON] }))).toEqual({
      kind: 'hold',
      reason: 'no-loser',
    });
  });

  it('over the cap holds as oversized — at the gate, so it costs ZERO reads', () => {
    const many = Array.from({ length: MAX_TRANSFER_IDS + 1 }, (_unused, i) => `uid-${i}`);
    expect(gateTransfer(transferEvent({ transferredFrom: many }))).toEqual({
      kind: 'hold',
      reason: 'oversized',
    });
  });

  it('exactly at the cap resolves (the boundary is inclusive)', () => {
    const many = Array.from({ length: MAX_TRANSFER_IDS }, (_unused, i) => `uid-${i}`);
    expect(gateTransfer(transferEvent({ transferredFrom: many }))).toMatchObject({ kind: 'resolve' });
  });

  // The filter/dedupe-BEFORE-cap ordering, pinned. Capping the RAW array would
  // hold on routine anonymous-alias accretion (the app mints a fresh anon id on
  // every sign-out), leaving the revoke path inert for exactly the churning
  // accounts that generate transfers.
  it('anon ids and duplicates do NOT count toward the cap (filter+dedupe run first)', () => {
    const anons = Array.from({ length: 12 }, (_unused, i) => `${RC_ANONYMOUS_PREFIX}${i}`);
    const gate = gateTransfer(
      transferEvent({ transferredFrom: [...anons, 'uid-a', 'uid-a'], transferredTo: ['uid-b'] }),
    );
    expect(gate).toEqual({ kind: 'resolve', fromIds: ['uid-a'], toIds: ['uid-b'] });
  });
});

describe('planTransfer — the case table (ADR-015 Decision 3)', () => {
  // (a) THE false-downgrade regression: a shared-Apple-ID restore inside one
  // couple. The mirror is COUPLE-scoped, so the entitlement did not move — only
  // which RC subscriber holds it. Revoking here downgrades a paying couple.
  it('(a) within one couple → hold(internal), nothing written', () => {
    expect(planTransfer([inCouple('uid-a', 'X')], [inCouple('uid-b', 'X')])).toEqual({
      kind: 'hold',
      reason: 'internal',
    });
  });

  it('(b) cross-couple → revoke exactly the loser lane (the gainer gets nothing)', () => {
    expect(planTransfer([inCouple('uid-a', 'X')], [inCouple('uid-b', 'Y')])).toEqual({
      kind: 'revoke',
      targets: [{ coupleId: 'X', uid: 'uid-a' }],
    });
  });

  it('(c) an unknown destination holds (it might be the loser under an id we cannot place)', () => {
    expect(planTransfer([inCouple('uid-a', 'X')], [unknown('uid-b')])).toEqual({
      kind: 'hold',
      reason: 'ambiguous-destination',
    });
  });

  it('(c) one unknown among known destinations still holds (FULLY known, or hold)', () => {
    expect(
      planTransfer([inCouple('uid-a', 'X')], [inCouple('uid-b', 'Y'), unknown('uid-z')]),
    ).toEqual({ kind: 'hold', reason: 'ambiguous-destination' });
  });

  it("(c') a known-but-unpaired destination is NOT ambiguous → revoke", () => {
    expect(planTransfer([inCouple('uid-a', 'X')], [unpaired('uid-b')])).toEqual({
      kind: 'revoke',
      targets: [{ coupleId: 'X', uid: 'uid-a' }],
    });
  });

  it('(d) no loser resolves to a couple → hold(no-loser); a TRANSFER never grants', () => {
    expect(planTransfer([unpaired('uid-a')], [inCouple('uid-b', 'Y')])).toEqual({
      kind: 'hold',
      reason: 'no-loser',
    });
  });

  it('(e) neither side resolves → hold(no-loser)', () => {
    expect(planTransfer([unknown('uid-a')], [unpaired('uid-b')])).toEqual({
      kind: 'hold',
      reason: 'no-loser',
    });
  });

  it('(f) multiple losers on different couples → one target each', () => {
    expect(
      planTransfer(
        [inCouple('uid-a', 'X'), inCouple('uid-c', 'Z')],
        [inCouple('uid-b', 'Y')],
      ),
    ).toEqual({
      kind: 'revoke',
      targets: [
        { coupleId: 'X', uid: 'uid-a' },
        { coupleId: 'Z', uid: 'uid-c' },
      ],
    });
  });

  it('(f) a mixed destination containing the loser’s own couple holds it harmless', () => {
    // uid-a's couple X is among the destinations ⇒ X keeps its entitlement; the
    // OTHER loser (couple Z) still lost it and is revoked.
    expect(
      planTransfer(
        [inCouple('uid-a', 'X'), inCouple('uid-c', 'Z')],
        [inCouple('uid-b', 'X')],
      ),
    ).toEqual({ kind: 'revoke', targets: [{ coupleId: 'Z', uid: 'uid-c' }] });
  });
});

describe('revokedLane / revokeLane — the tombstone (ADR-015 Decision 4)', () => {
  it('is a PURE projection of the event: entitled false, expiry = the transfer instant', () => {
    const event = transferEvent({ eventTimestampMs: 5_000, store: 'APP_STORE', environment: 'SANDBOX' });
    expect(revokedLane(event)).toEqual({
      entitled: false,
      productId: null,
      periodType: null,
      // NOT null — null is the non-expiring sentinel and would mint free premium.
      expiresAtMs: 5_000,
      willRenew: false,
      store: 'APP_STORE',
      environment: 'SANDBOX',
      entitlementIds: null,
    });
  });

  it('never copies the loser’s previous lane facts (convergence depends on this)', () => {
    const lanes = { 'uid-a': lane({ productId: 'premium.yearly', expiresAtMs: 90_000 }) };
    const next = revokeLane(lanes, 'uid-a', transferEvent({ eventTimestampMs: 5_000 }), 7);
    expect(next['uid-a']).toMatchObject({
      entitled: false,
      productId: null,
      expiresAtMs: 5_000,
      entitlementIds: null,
    });
  });

  it('writes a tombstone even when the lane does not exist yet', () => {
    // Otherwise a late INITIAL_PURCHASE (older ts) resurrects a moved-away
    // entitlement — the transfer-before-the-purchase-it-moves hazard.
    const next = revokeLane({}, 'uid-a', transferEvent({ eventTimestampMs: 5_000 }), 7);
    expect(next['uid-a']).toMatchObject({ entitled: false, lastEventTimestampMs: 5_000 });
  });

  it('is guarded by the SAME total order: a replay returns the same reference', () => {
    const event = transferEvent();
    const first = revokeLane({}, 'uid-a', event, 7);
    expect(revokeLane(first, 'uid-a', event, 99)).toBe(first);
  });

  it('a STALE transfer cannot re-revoke a lane a newer renewal already advanced', () => {
    const lanes = { 'uid-a': lane({ lastEventTimestampMs: 9_000, lastEventId: 'evt-new' }) };
    expect(revokeLane(lanes, 'uid-a', transferEvent({ eventTimestampMs: 5_000 }), 7)).toBe(lanes);
  });

  it('a NEWER transfer replaces an entitled lane with the tombstone', () => {
    const lanes = { 'uid-a': lane({ lastEventTimestampMs: 1_000, lastEventId: 'evt-1' }) };
    const next = revokeLane(lanes, 'uid-a', transferEvent({ eventTimestampMs: 5_000 }), 7);
    expect(next).not.toBe(lanes);
    expect(next['uid-a'].entitled).toBe(false);
  });
});

describe('deriveSummary with a tombstone', () => {
  it('a revoked lane never outranks a still-entitled sibling lane (lane isolation)', () => {
    const summary = deriveSummary({
      'uid-a': { ...revokedLane(transferEvent({ eventTimestampMs: 5_000 })), lastEventId: 'evt-t1', lastEventTimestampMs: 5_000, updatedAtMs: 0 },
      'uid-b': lane({ entitled: true, expiresAtMs: 9_000, productId: 'premium.yearly' }),
    });
    expect(summary).toMatchObject({ entitled: true, productId: 'premium.yearly', expiresAtMs: 9_000 });
  });

  it('all-revoked lanes ⇒ the couple is free', () => {
    const summary = deriveSummary({
      'uid-a': { ...revokedLane(transferEvent({ eventTimestampMs: 5_000 })), lastEventId: 'evt-t1', lastEventTimestampMs: 5_000, updatedAtMs: 0 },
    });
    expect(summary.entitled).toBe(false);
  });
});

describe('logProjection on a TRANSFER', () => {
  it('carries no identifiers — never the transfer arrays', () => {
    const fields = logProjection(transferEvent(), 'transfer-hold:internal');
    expect(fields).toEqual({
      type: 'TRANSFER',
      id: 'evt-t1',
      environment: 'PRODUCTION',
      decision: 'transfer-hold:internal',
    });
    expect(JSON.stringify(fields)).not.toContain('uid-a');
  });
});
