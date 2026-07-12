// In-process tests of the coachProxy HANDLER (ADR-016 Decisions 1/2/7/8) against
// the firestore emulator with an injected db + FixtureCoachProvider. These seed
// couples/subscriptions/coachUsage — collections that fire NO functions-emulator
// trigger — so plain adminFirestore/demo-hayati is correct (the answerReveal
// trigger only watches couples/.../answers). The onCall handler takes a
// CallableRequest-shaped object (the create-invite-handler mold). The e2e HTTP
// protocol is covered in coach-proxy-callable.test.ts.
import { Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError } from 'firebase-functions/v2/https';
import type { CallableRequest } from 'firebase-functions/v2/https';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  CoachResponse,
  COACH_RATE_LIMIT,
  COACH_RATE_WINDOW_MS,
  makeCoachProxyHandler,
} from '../../src/coach/coach-proxy';
import { DEFAULT_CAPS, computePeriodKeys } from '../../src/coach/coach-core';
import { refundCoachTurn } from '../../src/coach/coach-service';
import { CoachProvider, FixtureCoachProvider } from '../../src/coach/provider-port';
import { createRateLimiter } from '../../src/invites/invite-preview';
import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();

const COUPLE = 'couple-1';
const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const CHARLIE = 'charlie-uid';
const TZ = 'Europe/Istanbul';
const NOW_MS = Date.UTC(2026, 6, 12, 12, 0, 0); // 2026-07-12T12:00Z → Istanbul 15:00
const KEYS = computePeriodKeys(NOW_MS, TZ); // { dayKey: '20260712', monthKey: '202607' }
const SENTINEL = 'HAYATI_SENTINEL_7f3a';
const BENIGN_REPLY = 'That sounds lovely. Tell me a little more about your week.';
const CRISIS_REPLY = "I understand. Honestly, sometimes I want to die too — but let's talk about it.";

const now = () => NOW_MS;

function authedRequest(uid: string | undefined, data: unknown): CallableRequest {
  return { auth: uid === undefined ? undefined : { uid }, data } as unknown as CallableRequest;
}

function validData(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    coupleId: COUPLE,
    personaId: 'coach',
    language: 'tr',
    register: 'tr-playful',
    messages: [{ role: 'user', text: 'merhaba nasilsin bugun' }],
    ...overrides,
  };
}

/** Builds a handler pinned to the emulator db + fixed clock; provider/caps/etc overridable. */
function makeHandler(
  overrides: Partial<Parameters<typeof makeCoachProxyHandler>[0]> = {},
): (req: CallableRequest) => Promise<CoachResponse> {
  return makeCoachProxyHandler({ db: () => db, now, ...overrides });
}

async function seedCouple(memberUids: string[] = [ALICE, BOB], timezone: string = TZ): Promise<void> {
  await db.collection('couples').doc(COUPLE).set({ memberUids, timezone });
}

async function seedPremium(sub: { entitled: boolean; expiresAtMs: number | null }): Promise<void> {
  await db.collection('subscriptions').doc(COUPLE).set(sub);
}

const parentRef = () => db.collection('coachUsage').doc(COUPLE);
const dailyRef = (uid: string) => parentRef().collection('daily').doc(uid);

async function expectHttpsError(
  run: Promise<unknown>,
  code: string,
  reason?: string,
): Promise<HttpsError> {
  const error = (await run.then(
    () => {
      throw new Error(`expected HttpsError '${code}' but the call resolved`);
    },
    (thrown) => thrown,
  )) as HttpsError;
  expect(error).toBeInstanceOf(HttpsError);
  expect(error.code).toBe(code);
  if (reason !== undefined) {
    expect(error.details).toMatchObject({ reason });
  }
  return error;
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('coachProxy handler — auth + rate limit (Decision 2 steps 1-2)', () => {
  it('rejects a missing auth context with unauthenticated', async () => {
    await expectHttpsError(makeHandler()(authedRequest(undefined, validData())), 'unauthenticated');
  });

  it('rejects an empty uid with unauthenticated (emulator garbage-token guard)', async () => {
    await expectHttpsError(makeHandler()(authedRequest('', validData())), 'unauthenticated');
  });

  it('the 31st call within a minute is rate-limited (resource-exhausted / rate-limited)', async () => {
    // One handler instance → one limiter, fixed clock so the window never rolls.
    const handler = makeHandler({ rateLimiter: createRateLimiter(COACH_RATE_LIMIT, COACH_RATE_WINDOW_MS, now) });
    // 30 calls pass the limiter (they fail later at validation — junk body — but
    // each consumed a token). The 31st trips the limiter before anything else.
    for (let i = 0; i < COACH_RATE_LIMIT; i++) {
      await handler(authedRequest(ALICE, { junk: true })).catch(() => undefined);
    }
    await expectHttpsError(handler(authedRequest(ALICE, { junk: true })), 'resource-exhausted', 'rate-limited');
  });
});

describe('coachProxy handler — crisis pre-scan (Decision 2 step 3; test commitment 1)', () => {
  it('a crisis phrase in a user message → help path, zero port calls, zero Firestore docs', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const res = await makeHandler({ provider })(
      authedRequest(ALICE, validData({ messages: [{ role: 'user', text: `intihar ${SENTINEL}` }] })),
    );
    expect(res).toMatchObject({ kind: 'help', category: 'selfHarm' });
    expect(res.remaining).toBeUndefined();
    expect(provider.calls).toHaveLength(0);
    expect((await parentRef().get()).exists).toBe(false);
    expect((await dailyRef(ALICE).get()).exists).toBe(false);
  });

  it('a crisis phrase in a NON-user (assistant) message still routes to help (every role scanned)', async () => {
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const res = await makeHandler({ provider })(
      authedRequest(
        ALICE,
        validData({
          messages: [
            { role: 'assistant', text: 'kendimi öldüreceğim' },
            { role: 'user', text: 'hello' },
          ],
        }),
      ),
    );
    expect(res.kind).toBe('help');
    expect(provider.calls).toHaveLength(0);
  });

  it('a phrase split across two messages hits via the concatenation scan', async () => {
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const res = await makeHandler({ provider })(
      authedRequest(
        ALICE,
        validData({
          messages: [
            { role: 'assistant', text: 'yaşamak' },
            { role: 'user', text: 'istemiyorum' },
          ],
        }),
      ),
    );
    expect(res.kind).toBe('help');
    expect(provider.calls).toHaveLength(0);
  });

  it('an oversize (2400-char) crisis message → help path, NOT invalid-argument (the ordering pin)', async () => {
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const oversize = `${'x'.repeat(2400)} intihar`; // > MAX_MESSAGE_CHARS, would be invalid
    const res = await makeHandler({ provider })(
      authedRequest(ALICE, validData({ messages: [{ role: 'user', text: oversize }] })),
    );
    expect(res).toMatchObject({ kind: 'help', category: 'selfHarm' });
    expect(provider.calls).toHaveLength(0);
  });

  it('a detector throw fails closed to the help path (safety doubt never routes to persona)', async () => {
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const res = await makeHandler({
      provider,
      detectCrisis: () => {
        throw new Error('normalizer boom');
      },
    })(authedRequest(ALICE, validData()));
    expect(res.kind).toBe('help');
    expect(res.category).toBeUndefined(); // no category known on a fail-closed throw
    expect(provider.calls).toHaveLength(0);
  });
});

describe('coachProxy handler — validation (Decision 2 step 4)', () => {
  it.each([
    ['bad personaId', { personaId: 'wizard' }],
    ['bad language', { language: 'de' }],
    ['bad register', { register: 'tr-formal' }],
    ['bad coupleId', { coupleId: '' }],
    ['no messages', { messages: [] }],
    ['too many messages', { messages: Array.from({ length: 21 }, () => ({ role: 'user', text: 'hi' })) }],
    ['message too long', { messages: [{ role: 'user', text: 'y'.repeat(2001) }] }],
    ['last not user', { messages: [{ role: 'assistant', text: 'hi there' }] }],
  ])('%s → invalid-argument', async (_name, override) => {
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    await expectHttpsError(makeHandler({ provider })(authedRequest(ALICE, validData(override))), 'invalid-argument');
    expect(provider.calls).toHaveLength(0);
  });

  it('a non-object body → invalid-argument', async () => {
    await expectHttpsError(makeHandler()(authedRequest(ALICE, 'not-an-object')), 'invalid-argument');
  });
});

describe('coachProxy handler — membership (Decision 2 step 5a)', () => {
  it('a non-member uid → permission-denied, zero port calls, zero cap docs', async () => {
    await seedCouple([ALICE, BOB]);
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    await expectHttpsError(makeHandler({ provider })(authedRequest(CHARLIE, validData())), 'permission-denied');
    expect(provider.calls).toHaveLength(0);
    expect((await parentRef().get()).exists).toBe(false);
  });

  it('an absent couple doc → permission-denied (not-member, fail-closed before any key derivation)', async () => {
    await expectHttpsError(makeHandler()(authedRequest(ALICE, validData())), 'permission-denied');
  });
});

describe('coachProxy handler — premium gate (Decision 6; test commitment 3)', () => {
  it.each<[string, { entitled: boolean; expiresAtMs: number | null } | null]>([
    ['absent subscriptions doc', null],
    ['entitled:false', { entitled: false, expiresAtMs: NOW_MS + 1_000_000 }],
    ['entitled:true + past expiry', { entitled: true, expiresAtMs: NOW_MS - 1_000 }],
  ])('%s → failed-precondition/not-premium, zero cap consumption, zero port calls', async (_name, sub) => {
    await seedCouple();
    if (sub) {
      await seedPremium(sub);
    }
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    await expectHttpsError(makeHandler({ provider })(authedRequest(ALICE, validData())), 'failed-precondition', 'not-premium');
    expect(provider.calls).toHaveLength(0);
    expect((await parentRef().get()).exists).toBe(false);
    expect((await dailyRef(ALICE).get()).exists).toBe(false);
  });

  it.each<[string, { entitled: boolean; expiresAtMs: number | null }]>([
    ['null expiry (non-expiring)', { entitled: true, expiresAtMs: null }],
    ['future expiry', { entitled: true, expiresAtMs: NOW_MS + 1_000 }],
  ])('premium %s → reply, cap consumed, port called once', async (_name, sub) => {
    await seedCouple();
    await seedPremium(sub);
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const res = await makeHandler({ provider })(authedRequest(ALICE, validData()));
    expect(res).toMatchObject({ kind: 'reply', text: BENIGN_REPLY });
    expect(res.remaining).toEqual({
      daily: DEFAULT_CAPS.dailyPerUser - 1,
      monthly: DEFAULT_CAPS.monthlyPerCouple - 1,
    });
    expect(provider.calls).toHaveLength(1);
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(1);
    expect((await parentRef().get()).data()!.monthly).toMatchObject({ monthKey: KEYS.monthKey, count: 1 });
  });
});

describe('coachProxy handler — caps (Decision 7; test commitment 2)', () => {
  it('drives the DAILY lane to cap → resource-exhausted/cap-daily, no extra port call', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const handler = makeHandler({ provider, caps: { dailyPerUser: 2, monthlyPerCouple: 1000 } });

    await handler(authedRequest(ALICE, validData()));
    await handler(authedRequest(ALICE, validData()));
    await expectHttpsError(handler(authedRequest(ALICE, validData())), 'resource-exhausted', 'cap-daily');

    expect(provider.calls).toHaveLength(2); // the capped call never reached the port
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(2);
  });

  it('drives the MONTHLY bucket to cap → resource-exhausted/cap-monthly', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const handler = makeHandler({ provider, caps: { dailyPerUser: 30, monthlyPerCouple: 2 } });

    await handler(authedRequest(ALICE, validData()));
    await handler(authedRequest(BOB, validData())); // couple-shared bucket
    await expectHttpsError(handler(authedRequest(ALICE, validData())), 'resource-exhausted', 'cap-monthly');

    expect(provider.calls).toHaveLength(2);
    expect((await parentRef().get()).data()!.monthly.count).toBe(2);
  });

  it('malformed usage docs are treated as empty and reserve proceeds', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    await parentRef().set({ monthly: 'not-an-object' });
    await dailyRef(ALICE).set({ dayKey: 123, count: 'nope' });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);

    const res = await makeHandler({ provider })(authedRequest(ALICE, validData()));
    expect(res.kind).toBe('reply');
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(1);
  });
});

describe('coachProxy handler — internal (bad timezone, Decision 2 step 5c)', () => {
  it('an invalid couple timezone → internal (defensively mapped, never a raw throw)', async () => {
    await seedCouple([ALICE, BOB], 'Invalid/Zone');
    await seedPremium({ entitled: true, expiresAtMs: null });
    await expectHttpsError(makeHandler()(authedRequest(ALICE, validData())), 'internal');
  });
});

describe('coachProxy handler — provider failure (Decision 2 step 6; test commitment 4)', () => {
  it('a ProviderUnavailableError → unavailable, and BOTH lanes are refunded', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ throws: 'upstream-error' }]);

    await expectHttpsError(makeHandler({ provider })(authedRequest(ALICE, validData())), 'unavailable');

    expect((await dailyRef(ALICE).get()).data()!.count).toBe(0); // reserved 0→1 then refunded 1→0
    expect((await parentRef().get()).data()!.monthly.count).toBe(0);
  });

  it('a non-ProviderUnavailableError throw → unavailable (classification falls back to unknown)', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider: CoachProvider = {
      generateReply: async () => {
        throw new Error('kaboom');
      },
    };
    await expectHttpsError(makeHandler({ provider })(authedRequest(ALICE, validData())), 'unavailable');
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(0);
  });
});

describe('coachProxy handler — post-filter (Decision 2 step 7; test commitment 5)', () => {
  it('a fixture reply containing crisis text → kind:help, cap stays consumed', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: CRISIS_REPLY }]);

    const res = await makeHandler({ provider })(authedRequest(ALICE, validData()));
    expect(res).toMatchObject({ kind: 'help', category: 'selfHarm' });
    expect(res.remaining).toEqual({
      daily: DEFAULT_CAPS.dailyPerUser - 1,
      monthly: DEFAULT_CAPS.monthlyPerCouple - 1,
    });
    expect(provider.calls).toHaveLength(1);
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(1); // cap consumed — the provider was paid
  });

  it('a post-filter detector throw fails closed to help (cap already consumed)', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: 'REPLYMARK persona output' }]);
    // A detector that clears the (benign) request but throws on the reply text.
    const detectCrisis = (texts: readonly string[]) => {
      if (texts.some((t) => t.includes('REPLYMARK'))) {
        throw new Error('post-filter boom');
      }
      return { hit: false } as const;
    };
    const res = await makeHandler({ provider, detectCrisis })(authedRequest(ALICE, validData()));
    expect(res.kind).toBe('help');
    expect(res.remaining).toEqual({
      daily: DEFAULT_CAPS.dailyPerUser - 1,
      monthly: DEFAULT_CAPS.monthlyPerCouple - 1,
    });
  });
});

describe('refundCoachTurn — per-lane captured-key guard (test commitment 4)', () => {
  async function seedLanes(daily: { dayKey: string; count: number }, monthly: { monthKey: string; count: number }): Promise<void> {
    await parentRef().set({ monthly });
    await dailyRef(ALICE).set(daily);
  }

  it('both keys match → both lanes decrement', async () => {
    await seedLanes({ dayKey: KEYS.dayKey, count: 5 }, { monthKey: KEYS.monthKey, count: 5 });
    const out = await refundCoachTurn(db, {
      coupleId: COUPLE,
      uid: ALICE,
      reservedDayKey: KEYS.dayKey,
      reservedMonthKey: KEYS.monthKey,
    });
    expect(out).toEqual({ kind: 'refunded', daily: true, monthly: true });
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(4);
    expect((await parentRef().get()).data()!.monthly.count).toBe(4);
  });

  it('a period rollover (daily matches, monthly does not) refunds only the daily lane', async () => {
    await seedLanes({ dayKey: KEYS.dayKey, count: 5 }, { monthKey: '209901', count: 5 });
    const out = await refundCoachTurn(db, {
      coupleId: COUPLE,
      uid: ALICE,
      reservedDayKey: KEYS.dayKey,
      reservedMonthKey: KEYS.monthKey,
    });
    expect(out).toEqual({ kind: 'refunded', daily: true, monthly: false });
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(4);
    expect((await parentRef().get()).data()!.monthly.count).toBe(5); // rolled lane untouched
  });

  it('both keys mismatched → writes nothing to either lane', async () => {
    await seedLanes({ dayKey: '19990101', count: 5 }, { monthKey: '199901', count: 5 });
    const out = await refundCoachTurn(db, {
      coupleId: COUPLE,
      uid: ALICE,
      reservedDayKey: KEYS.dayKey,
      reservedMonthKey: KEYS.monthKey,
    });
    expect(out).toEqual({ kind: 'refunded', daily: false, monthly: false });
    expect((await dailyRef(ALICE).get()).data()!.count).toBe(5);
    expect((await parentRef().get()).data()!.monthly.count).toBe(5);
  });

  it('a refund whose transaction fails is swallowed → refund-failed (units stay burned)', async () => {
    const badDb = {
      collection: () => ({ doc: () => ({ collection: () => ({ doc: () => ({}) }) }) }),
      runTransaction: async () => {
        throw new Error('firestore fell over');
      },
    } as unknown as Firestore;
    const out = await refundCoachTurn(badDb, {
      coupleId: COUPLE,
      uid: ALICE,
      reservedDayKey: KEYS.dayKey,
      reservedMonthKey: KEYS.monthKey,
    });
    expect(out).toEqual({ kind: 'refund-failed' });
  });
});

// --- Sentinel / log perimeter (Decision 8; test commitment 6) ----------------
describe('coachProxy handler — sentinel / no-leak perimeter', () => {
  let captured: string[];
  let spies: Array<{ mockRestore: () => void }>;

  beforeEach(() => {
    captured = [];
    const record = (...args: unknown[]): void => {
      captured.push(args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' '));
    };
    spies = [
      vi.spyOn(logger, 'info').mockImplementation(record),
      vi.spyOn(logger, 'warn').mockImplementation(record),
      vi.spyOn(logger, 'error').mockImplementation(record),
      vi.spyOn(console, 'log').mockImplementation(record),
      vi.spyOn(console, 'error').mockImplementation(record),
      vi.spyOn(console, 'warn').mockImplementation(record),
    ];
  });

  afterEach(() => {
    spies.forEach((s) => s.mockRestore());
  });

  const allLogs = (): string => captured.join('\n');
  const sentinelMsg = (text: string) => validData({ messages: [{ role: 'user', text: `${text} ${SENTINEL}` }] });

  /** Runs a handler call, asserting any rejection is a (static-message) HttpsError. */
  async function runNoEscape(promise: Promise<CoachResponse>): Promise<void> {
    await promise.then(
      () => undefined,
      (error) => {
        expect(error).toBeInstanceOf(HttpsError);
        expect((error as HttpsError).message).not.toContain(SENTINEL);
      },
    );
  }

  it('crisis path: sentinel never logged, and the crisis line carries no coupleId', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    await runNoEscape(makeHandler({ provider })(authedRequest(ALICE, sentinelMsg('intihar'))));

    expect(allLogs()).not.toContain(SENTINEL);
    const crisisLine = captured.find((l) => l.includes('"outcome":"crisis"'));
    expect(crisisLine).toBeDefined();
    expect(crisisLine).not.toContain(COUPLE); // Decision 8: crisis lines drop coupleId
  });

  it('persona-reply path: sentinel in the request never reaches a log', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    await runNoEscape(makeHandler({ provider })(authedRequest(ALICE, sentinelMsg('hello'))));
    expect(allLogs()).not.toContain(SENTINEL);
  });

  it('cap-exhausted path: sentinel never logged', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    await parentRef().set({ monthly: { monthKey: KEYS.monthKey, count: 1000 } });
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    await runNoEscape(makeHandler({ provider })(authedRequest(ALICE, sentinelMsg('hello'))));
    expect(allLogs()).not.toContain(SENTINEL);
  });

  it('provider-failure path: neither the sentinel nor the error message is logged', async () => {
    await seedCouple();
    await seedPremium({ entitled: true, expiresAtMs: null });
    const provider: CoachProvider = {
      generateReply: async () => {
        throw new Error(`upstream said ${SENTINEL}`);
      },
    };
    await runNoEscape(makeHandler({ provider })(authedRequest(ALICE, sentinelMsg('hello'))));
    expect(allLogs()).not.toContain(SENTINEL);
  });

  it('forced normalizer throw: the thrown error message is never logged', async () => {
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    await runNoEscape(
      makeHandler({
        provider,
        detectCrisis: () => {
          throw new Error(`normalizer exploded with ${SENTINEL}`);
        },
      })(authedRequest(ALICE, sentinelMsg('hello'))),
    );
    expect(allLogs()).not.toContain(SENTINEL);
  });

  it('a non-HttpsError escape (db resolution throws) is converted to a static internal', async () => {
    const provider = new FixtureCoachProvider([{ text: BENIGN_REPLY }]);
    const handler = makeCoachProxyHandler({
      now,
      provider,
      db: () => {
        throw new Error(`db boom ${SENTINEL}`);
      },
    });
    const error = await expectHttpsError(handler(authedRequest(ALICE, sentinelMsg('hello'))), 'internal');
    expect(error.message).not.toContain(SENTINEL);
    expect(allLogs()).not.toContain(SENTINEL);
  });
});
