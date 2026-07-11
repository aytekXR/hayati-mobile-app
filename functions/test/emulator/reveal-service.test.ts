// M3.4 reveal service against the firestore emulator (docs/resume-prompt.md
// Session 014, ADR-012 Decision 1 & 3). THE acceptance criteria for the reveal
// trigger, proven at the SERVICE level (the M3.2 pattern): the transactional
// revealedAt+streak latch, its idempotency under duplicate delivery and the
// two-answers race, and the post-commit best-effort push policy. The trigger
// WIRE is a thin e2e (answer-trigger-e2e.test.ts); this suite carries the proof.
//
// Clocks are always injected: quiet-hours resolution reads couple-local wall
// time, so a real `new Date()` would make send assertions flake by hour. NOON is
// Istanbul 12:00 (sends allowed); QUIET is Istanbul 23:00 (suppressed).
import { Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { composePush } from '../../src/notifications/payload-policy';
import type { RevealServiceDeps } from '../../src/streak/reveal-service';
import { handleAnswerCreated } from '../../src/streak/reveal-service';
import { clearNoTriggerFirestore, noTriggerFirestore } from '../support/admin';
import { FakeMessagingPort } from '../support/fake-messaging-port';

// The NO_TRIGGER project (admin.ts): the functions emulator does NOT watch it,
// so seeding answer docs here never fires the live answerReveal trigger — the
// service under test is the ONLY revealer, making every 'revealed' vs
// 'already-revealed' assertion deterministic. On demo-hayati the trigger would
// race these drives (the e2e suite covers that wire on purpose).
const db = noTriggerFirestore();
const couples = db.collection('couples');

const CID = 'couple-1';
const UID_A = 'uid-a';
const UID_B = 'uid-b';
const DAY_KEY = '20260710';
const TZ = 'Europe/Istanbul';

// Istanbul is a permanent +03 zone (no DST since 2016): 09:00Z = 12:00 local
// (outside quiet hours), 20:00Z = 23:00 local (inside the 22:00–08:00 window).
const NOON = new Date('2026-07-10T09:00:00Z');
const QUIET = new Date('2026-07-10T20:00:00Z');

function coupleRef(cid = CID) {
  return couples.doc(cid);
}
function dayRef(cid = CID, dayKey = DAY_KEY) {
  return coupleRef(cid).collection('days').doc(dayKey);
}
function answerRef(uid: string, cid = CID, dayKey = DAY_KEY) {
  return dayRef(cid, dayKey).collection('answers').doc(uid);
}

interface StreakSeed {
  count: number;
  lastMutualDate: string | null;
  graceTokens: number;
}

function seedCouple(opts: { streak?: StreakSeed | unknown; cid?: string } = {}): Promise<unknown> {
  const cid = opts.cid ?? CID;
  return coupleRef(cid).set({
    memberUids: [UID_A, UID_B],
    timezone: TZ,
    createdAt: Timestamp.now(),
    ...('streak' in opts ? { streak: opts.streak } : {}),
  });
}

function seedDay(opts: { revealedAt?: boolean; cid?: string; dayKey?: string } = {}): Promise<unknown> {
  return dayRef(opts.cid, opts.dayKey).set({
    questionId: 'solo_tr_001',
    packId: 'solo_tr',
    packVersion: 1,
    assignedAt: Timestamp.now(),
    ...(opts.revealedAt ? { revealedAt: Timestamp.now() } : {}),
  });
}

function seedAnswer(uid: string, opts: { cid?: string; dayKey?: string } = {}): Promise<unknown> {
  return answerRef(uid, opts.cid, opts.dayKey).set({
    questionId: 'solo_tr_001',
    text: `answer from ${uid}`,
    answeredAt: Timestamp.now(),
  });
}

function seedUser(uid: string, opts: { fcmTokens?: unknown; contentLanguage?: string } = {}): Promise<unknown> {
  return db.collection('users').doc(uid).set({
    contentLanguage: opts.contentLanguage ?? 'en',
    ...('fcmTokens' in opts ? { fcmTokens: opts.fcmTokens } : { fcmTokens: [`tok-${uid}`] }),
  });
}

function evt(authorUid: string, opts: { cid?: string; dayKey?: string } = {}) {
  return { coupleId: opts.cid ?? CID, dayKey: opts.dayKey ?? DAY_KEY, authorUid };
}

const noonDeps: RevealServiceDeps = { now: () => NOON };

async function readStreak(cid = CID): Promise<unknown> {
  return (await coupleRef(cid).get()).get('streak');
}
async function readRevealedAt(cid = CID, dayKey = DAY_KEY): Promise<unknown> {
  return (await dayRef(cid, dayKey).get()).get('revealedAt');
}

beforeEach(async () => {
  await clearNoTriggerFirestore();
});

describe('handleAnswerCreated — reveal latch (ADR-012 D1/D2)', () => {
  it('both answers, unrevealed → stamps revealedAt and folds the zero-state streak (0→1)', async () => {
    await seedCouple(); // no streak field → the INITIAL zero state
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);

    // Second answerer (UID_B) is the create that fires the trigger.
    const port = new FakeMessagingPort();
    const outcome = await handleAnswerCreated(db, port, evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('revealed');
    expect(outcome.streakApplied).toBe(true);
    expect(outcome.streakCorrupt).toBe(false);
    expect(await readRevealedAt()).toBeInstanceOf(Timestamp);
    expect(await readStreak()).toEqual({ count: 1, lastMutualDate: DAY_KEY, graceTokens: 1 });
  });

  it('a consecutive mutual day increments the streak (1→2), same ISO week keeps the token', async () => {
    await seedCouple({ streak: { count: 1, lastMutualDate: '20260709', graceTokens: 1 } });
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);

    const outcome = await handleAnswerCreated(db, new FakeMessagingPort(), evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('revealed');
    expect(await readStreak()).toEqual({ count: 2, lastMutualDate: DAY_KEY, graceTokens: 1 });
  });

  it('a one-day gap with a token bridges (grace consumed): count+1, token→0', async () => {
    // last = 20260708, dayKey = 20260710 (exactly one missed day, same ISO week).
    await seedCouple({ streak: { count: 3, lastMutualDate: '20260708', graceTokens: 1 } });
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);

    await handleAnswerCreated(db, new FakeMessagingPort(), evt(UID_B), noonDeps);

    expect(await readStreak()).toEqual({ count: 4, lastMutualDate: DAY_KEY, graceTokens: 0 });
  });

  it('a two-day gap resets the streak to 1 (no bridge past one missed day)', async () => {
    // last = 20260707, dayKey = 20260710 (two missed days).
    await seedCouple({ streak: { count: 3, lastMutualDate: '20260707', graceTokens: 1 } });
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);

    await handleAnswerCreated(db, new FakeMessagingPort(), evt(UID_B), noonDeps);

    expect(await readStreak()).toEqual({ count: 1, lastMutualDate: DAY_KEY, graceTokens: 1 });
  });

  it('a late older-day completion stamps revealedAt but never rewrites streak history', async () => {
    // dayKey 20260710 < lastMutualDate 20260712: the mutual-day record is true
    // (revealedAt stamps), streak count/lastMutualDate stay put (ADR-012 D2.3).
    await seedCouple({ streak: { count: 5, lastMutualDate: '20260712', graceTokens: 1 } });
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);

    const outcome = await handleAnswerCreated(db, new FakeMessagingPort(), evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('revealed');
    expect(await readRevealedAt()).toBeInstanceOf(Timestamp);
    expect(await readStreak()).toEqual({ count: 5, lastMutualDate: '20260712', graceTokens: 1 });
  });

  it('a malformed stored streak is applied from INITIAL and flagged/logged, not trusted', async () => {
    await seedCouple({ streak: 'corrupt-not-an-object' });
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);
    const errorSpy = vi.spyOn(logger, 'error');

    const outcome = await handleAnswerCreated(db, new FakeMessagingPort(), evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('revealed');
    expect(outcome.streakCorrupt).toBe(true);
    // Applied from INITIAL_STREAK → first-mutual-day result.
    expect(await readStreak()).toEqual({ count: 1, lastMutualDate: DAY_KEY, graceTokens: 1 });
    expect(errorSpy).toHaveBeenCalledWith(
      expect.stringContaining('malformed'),
      expect.objectContaining({ coupleId: CID }),
    );
    errorSpy.mockRestore();
  });
});

describe('handleAnswerCreated — idempotency & the two-answers race (exactly-once)', () => {
  it('duplicate delivery: re-driving the same event increments once, revealedAt unchanged', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);
    const port = new FakeMessagingPort();

    const first = await handleAnswerCreated(db, port, evt(UID_B), noonDeps);
    const revealedAtOnce = await readRevealedAt();
    const second = await handleAnswerCreated(db, port, evt(UID_B), noonDeps);

    expect(first.decision).toBe('revealed');
    expect(second.decision).toBe('already-revealed');
    expect(second.streakApplied).toBe(false);
    // ONE increment, the stamp is untouched by the duplicate, and the duplicate
    // sends nothing (only the latch winner pushes).
    expect(await readStreak()).toEqual({ count: 1, lastMutualDate: DAY_KEY, graceTokens: 1 });
    expect(await readRevealedAt()).toEqual(revealedAtOnce);
    expect(port.sent).toHaveLength(1);
  });

  it('two-answers race (Promise.all): concurrent drives yield exactly one reveal', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);
    await seedUser(UID_B);
    const port = new FakeMessagingPort();

    // Both creates fire "second"; the serializable transaction latch means one
    // commits the reveal and the other retries into already-revealed.
    const [a, b] = await Promise.all([
      handleAnswerCreated(db, port, evt(UID_A), noonDeps),
      handleAnswerCreated(db, port, evt(UID_B), noonDeps),
    ]);

    expect([a.decision, b.decision].sort()).toEqual(['already-revealed', 'revealed']);
    expect(await readStreak()).toEqual({ count: 1, lastMutualDate: DAY_KEY, graceTokens: 1 });
    expect(await readRevealedAt()).toBeInstanceOf(Timestamp);
    // Exactly one push — only the latch winner sends its reveal.
    expect(port.sent).toHaveLength(1);
  });

  it('forced interleave: a reveal committing under an in-flight read still yields exactly one', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);
    await seedUser(UID_B);
    const port = new FakeMessagingPort();

    // Gate A between its reads and its writes (attempt 0 only — a retry must not
    // re-block). The gate is released independently of B, so A always makes
    // progress: no deadlock regardless of the emulator's locking model.
    let signalRead: () => void = () => {};
    const readReached = new Promise<void>((res) => {
      signalRead = res;
    });
    let openGate: () => void = () => {};
    const gate = new Promise<void>((res) => {
      openGate = res;
    });
    const aDeps: RevealServiceDeps = {
      now: () => NOON,
      beforeWrite: async (attempt) => {
        if (attempt === 0) {
          signalRead();
          await gate;
        }
      },
    };

    const aPromise = handleAnswerCreated(db, port, evt(UID_A), aDeps);
    await readReached; // A has read both answers + the unrevealed day
    const bPromise = handleAnswerCreated(db, port, evt(UID_B), noonDeps);
    openGate(); // A proceeds to write; whichever commits first wins the latch

    const [a, b] = await Promise.all([aPromise, bPromise]);
    expect([a.decision, b.decision].sort()).toEqual(['already-revealed', 'revealed']);
    expect(await readStreak()).toEqual({ count: 1, lastMutualDate: DAY_KEY, graceTokens: 1 });
    expect(await readRevealedAt()).toBeInstanceOf(Timestamp);
    expect(port.sent).toHaveLength(1);
  });
});

describe('handleAnswerCreated — push policy (ADR-012 D3, post-commit best-effort)', () => {
  it('one answer only → no reveal; a partnerAnswered nudge goes to the non-answerer', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A); // only UID_A has answered
    await seedUser(UID_B); // the nudge recipient (has NOT answered)
    const port = new FakeMessagingPort();

    const outcome = await handleAnswerCreated(db, port, evt(UID_A), noonDeps);

    expect(outcome.decision).toBe('one-answer');
    expect(outcome.streakApplied).toBe(false);
    expect(await readRevealedAt()).toBeUndefined();
    // The payload is byte-identical to composePush's partnerAnswered/en output,
    // to the partner's token — proving it came from the pure policy, not ad hoc.
    const expected = composePush({ kind: 'partnerAnswered', language: 'en', discreet: false });
    expect(port.sent).toEqual([{ token: `tok-${UID_B}`, title: expected.title, body: expected.body }]);
    expect(outcome.push).toMatchObject({ kind: 'partnerAnswered', recipientUid: UID_B, status: 'sent' });
  });

  it('reveal push goes to the FIRST answerer (partner of the create that triggered)', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A); // first answerer → reveal recipient
    await seedAnswer(UID_B);
    await seedUser(UID_A);
    const port = new FakeMessagingPort();

    await handleAnswerCreated(db, port, evt(UID_B), noonDeps);

    const expected = composePush({ kind: 'reveal', language: 'en', discreet: false });
    expect(port.sent).toEqual([{ token: `tok-${UID_A}`, title: expected.title, body: expected.body }]);
  });

  it('discreet mode (AR recipient) sends the generic payload — no event specifics', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A, { contentLanguage: 'ar' });
    const port = new FakeMessagingPort();

    await handleAnswerCreated(db, port, evt(UID_B), noonDeps);

    const expected = composePush({ kind: 'reveal', language: 'ar', discreet: true });
    expect(port.sent).toEqual([{ token: `tok-${UID_A}`, title: expected.title, body: expected.body }]);
  });

  it('quiet hours (couple-local 23:00) suppress the push; the reveal still commits', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);
    const port = new FakeMessagingPort();

    const outcome = await handleAnswerCreated(db, port, evt(UID_B), { now: () => QUIET });

    expect(outcome.decision).toBe('revealed');
    expect(await readRevealedAt()).toBeInstanceOf(Timestamp); // transaction committed
    expect(outcome.push).toMatchObject({ status: 'suppressed-quiet-hours', tokenCount: 1 });
    expect(port.sent).toHaveLength(0);
  });

  it('a missing recipient user doc is a typed loud skip; the reveal still commits', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    // No users/uid-a doc seeded.
    const port = new FakeMessagingPort();

    const outcome = await handleAnswerCreated(db, port, evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('revealed');
    expect(await readStreak()).toEqual({ count: 1, lastMutualDate: DAY_KEY, graceTokens: 1 });
    expect(outcome.push).toMatchObject({ status: 'no-user-doc' });
    expect(port.sent).toHaveLength(0);
  });

  it('an empty fcmTokens array is a typed loud skip; the reveal still commits', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A, { fcmTokens: [] });
    const port = new FakeMessagingPort();

    const outcome = await handleAnswerCreated(db, port, evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('revealed');
    expect(outcome.push).toMatchObject({ status: 'no-tokens', tokenCount: 0 });
    expect(port.sent).toHaveLength(0);
  });

  it('a send failure is counted and swallowed; the committed reveal is unaffected', async () => {
    await seedCouple();
    await seedDay();
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);
    await seedUser(UID_A);
    const port = new FakeMessagingPort();
    port.failOn(`tok-${UID_A}`);

    const outcome = await handleAnswerCreated(db, port, evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('revealed');
    expect(await readRevealedAt()).toBeInstanceOf(Timestamp);
    expect(outcome.push).toMatchObject({ status: 'send-failed', failedCount: 1, sentCount: 0 });
  });
});

describe('handleAnswerCreated — corrupt/absent state is a typed skip, never a throw', () => {
  it('a missing couple doc is a couple-missing skip with no writes', async () => {
    await seedDay(); // day under an unseeded couple (orphan)
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);

    const outcome = await handleAnswerCreated(db, new FakeMessagingPort(), evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('skipped');
    expect(outcome.skipReason).toBe('couple-missing');
    expect(await readRevealedAt()).toBeUndefined();
  });

  it('a missing day doc is a day-missing skip with no writes', async () => {
    await seedCouple();
    // No day doc; but seed both answer docs so the only absent read is the day.
    await seedAnswer(UID_A);
    await seedAnswer(UID_B);

    const outcome = await handleAnswerCreated(db, new FakeMessagingPort(), evt(UID_B), noonDeps);

    expect(outcome.decision).toBe('skipped');
    expect(outcome.skipReason).toBe('day-missing');
    expect(await readStreak()).toBeUndefined();
  });

  it('an author who is not a couple member is a not-a-member skip', async () => {
    await seedCouple();
    await seedDay();

    const outcome = await handleAnswerCreated(db, new FakeMessagingPort(), evt('stranger-uid'), noonDeps);

    expect(outcome.decision).toBe('skipped');
    expect(outcome.skipReason).toBe('not-a-member');
    expect(await readRevealedAt()).toBeUndefined();
  });
});
