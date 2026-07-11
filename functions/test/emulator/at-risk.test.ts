// M3.4 streak-at-risk push pass against the firestore emulator (docs/resume-prompt
// Session 014, ADR-012 Decision 3). Proven at the SERVICE level (the M3.2 pattern):
// the hour-20 gate (once per zone per day, sub-hour zones included), the
// eligibility rule (streak > 0 AND today's day doc unrevealed), non-answerer
// recipient selection, and the best-effort send policy behind the injected port.
//
// The pass is driven off the SAME timezone bucketing the assignment pass uses
// (bucketCouplesByTimezone) — that shared read is the ADR-012 D3 hard constraint,
// so every test builds the buckets exactly as the handler does and hands them in.
import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  AT_RISK_LOCAL_HOUR,
  deliverAtRiskPush,
  runStreakAtRisk,
} from '../../src/notifications/at-risk';
import { composePush } from '../../src/notifications/payload-policy';
import { bucketCouplesByTimezone } from '../../src/rollover/rollover-service';
import { clearNoTriggerFirestore, noTriggerFirestore } from '../support/admin';
import { FakeMessagingPort } from '../support/fake-messaging-port';

// NO_TRIGGER project (admin.ts): the functions emulator does not watch it, so
// seeding answer docs here never fires the live answerReveal trigger and races the
// pass under test. Same posture as reveal-service.test.ts.
const db = noTriggerFirestore();
const couples = db.collection('couples');

const UID_A = 'uid-a';
const UID_B = 'uid-b';
const TZ = 'Europe/Istanbul';
const DAY_KEY = '20260710';

// 2026-07-10T17:00:00Z: Istanbul (+03) reads 20:00 → the at-risk sweep fires;
// New York (EDT −04) reads 13:00 at the SAME instant → it does not.
const AT = new Date('2026-07-10T17:00:00Z');
// Asia/Kathmandu is +05:45: 15:00Z reads 20:45 → the sub-hour zone catches its
// hour-20 sweep on the same run its local clock crosses 20:xx.
const KTM_AT = new Date('2026-07-10T15:00:00Z');
// Istanbul 23:00 — inside the 22:00–08:00 quiet window (defense-in-depth check).
const QUIET_AT = new Date('2026-07-10T20:00:00Z');

interface StreakSeed {
  count: number;
  lastMutualDate: string | null;
  graceTokens: number;
}
const streakOf = (count: number): StreakSeed => ({ count, lastMutualDate: '20260709', graceTokens: 1 });

function seedCouple(
  cid: string,
  opts: { timezone?: string; streak?: StreakSeed | unknown; memberUids?: unknown } = {},
): Promise<unknown> {
  return couples.doc(cid).set({
    memberUids: 'memberUids' in opts ? opts.memberUids : [UID_A, UID_B],
    timezone: opts.timezone ?? TZ,
    createdAt: Timestamp.now(),
    ...('streak' in opts ? { streak: opts.streak } : {}),
  });
}

function seedDay(cid: string, opts: { revealedAt?: boolean; dayKey?: string } = {}): Promise<unknown> {
  return couples
    .doc(cid)
    .collection('days')
    .doc(opts.dayKey ?? DAY_KEY)
    .set({
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
      ...(opts.revealedAt ? { revealedAt: Timestamp.now() } : {}),
    });
}

function seedAnswer(cid: string, uid: string, dayKey = DAY_KEY): Promise<unknown> {
  return couples
    .doc(cid)
    .collection('days')
    .doc(dayKey)
    .collection('answers')
    .doc(uid)
    .set({ questionId: 'solo_tr_001', text: `answer from ${uid}`, answeredAt: Timestamp.now() });
}

function seedUser(uid: string, opts: { fcmTokens?: unknown; contentLanguage?: string } = {}): Promise<unknown> {
  return db.collection('users').doc(uid).set({
    contentLanguage: opts.contentLanguage ?? 'en',
    ...('fcmTokens' in opts ? { fcmTokens: opts.fcmTokens } : { fcmTokens: [`tok-${uid}`] }),
  });
}

beforeEach(async () => {
  await clearNoTriggerFirestore();
});

describe('runStreakAtRisk — hour-20 gate (ADR-012 D3)', () => {
  it('AT_RISK_LOCAL_HOUR is 20', () => {
    expect(AT_RISK_LOCAL_HOUR).toBe(20);
  });

  it('fires ONLY for the bucket at couple-local hour 20; a same-instant off-20 zone and a corrupt zone are untouched', async () => {
    await seedCouple('ist', { timezone: 'Europe/Istanbul', streak: streakOf(3) });
    await seedDay('ist');
    await seedUser(UID_A);
    await seedUser(UID_B);
    // Same instant, New York is 13:00 (not 20) — eligible in every other way but
    // never evaluated because its bucket is off-hour.
    await seedCouple('nyc', { timezone: 'America/New_York', streak: streakOf(5) });
    await seedDay('nyc');
    // A non-IANA stored zone buckets fine (coupleTimezone only checks non-empty)
    // but localHour throws on it — the pass must skip the bucket, never throw.
    await seedCouple('badzone', { timezone: 'Not/AZone', streak: streakOf(2) });

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    // Only Istanbul is checked; both its members are non-answerers → two pushes.
    expect(summary).toEqual({
      checked: 1,
      sent: 2,
      skippedNoToken: 0,
      skippedNoDay: 0,
      suppressedQuiet: 0,
      failed: 0,
    });
    expect(port.sent.map((m) => m.token).sort()).toEqual([`tok-${UID_A}`, `tok-${UID_B}`]);
  });

  it('a sub-hour-offset zone (Asia/Kathmandu +05:45) fires at its 20:45 sweep, not at a 22:45 one', async () => {
    await seedCouple('ktm', { timezone: 'Asia/Kathmandu', streak: streakOf(4) });
    await seedDay('ktm');
    await seedUser(UID_A);
    await seedUser(UID_B);
    const buckets = await bucketCouplesByTimezone(db);

    // At AT (17:00Z) Kathmandu is 22:45 (hour 22) → nothing.
    const offSummary = await runStreakAtRisk(db, AT, new FakeMessagingPort(), buckets);
    expect(offSummary.checked).toBe(0);
    expect(offSummary.sent).toBe(0);

    // At KTM_AT (15:00Z) Kathmandu is 20:45 (hour 20) → fires.
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, KTM_AT, port, buckets);
    expect(summary.checked).toBe(1);
    expect(summary.sent).toBe(2);
  });
});

describe('runStreakAtRisk — eligibility & recipient selection', () => {
  it('nobody answered → nudges BOTH members', async () => {
    await seedCouple('ist', { streak: streakOf(3) });
    await seedDay('ist');
    await seedUser(UID_A);
    await seedUser(UID_B);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(1);
    expect(summary.sent).toBe(2);
    expect(port.sent).toHaveLength(2);
  });

  it('one answered → nudges ONLY the non-answerer, with the streak-count payload from the pure policy', async () => {
    await seedCouple('ist', { streak: streakOf(3) });
    await seedDay('ist');
    await seedAnswer('ist', UID_A); // UID_A already answered
    await seedUser(UID_A);
    await seedUser(UID_B);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(1);
    expect(summary.sent).toBe(1);
    // Byte-identical to composePush's streakAtRisk/en/count=3 output, to the
    // non-answerer's token — proving the payload came from the shared pure policy.
    const expected = composePush({ kind: 'streakAtRisk', language: 'en', discreet: false, streakCount: 3 });
    expect(port.sent).toEqual([{ token: `tok-${UID_B}`, title: expected.title, body: expected.body }]);
  });

  it('a revealed day is the healthy case → nothing sent, nothing counted', async () => {
    await seedCouple('ist', { streak: streakOf(3) });
    await seedDay('ist', { revealedAt: true });
    await seedUser(UID_A);
    await seedUser(UID_B);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(0);
    expect(summary.sent).toBe(0);
    expect(summary.skippedNoDay).toBe(0);
    expect(port.sent).toHaveLength(0);
  });

  it('a zero-count streak has nothing to lose → nothing', async () => {
    await seedCouple('ist', { streak: { count: 0, lastMutualDate: null, graceTokens: 1 } });
    await seedDay('ist');
    await seedUser(UID_A);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(0);
    expect(summary.sent).toBe(0);
    expect(port.sent).toHaveLength(0);
  });

  it('an absent streak field reads as zero → nothing', async () => {
    await seedCouple('ist'); // no streak field
    await seedDay('ist');
    await seedUser(UID_A);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(0);
    expect(summary.sent).toBe(0);
  });

  it('streak > 0 but NO day doc → a SEPARATE skippedNoDay skip (rollover failed earlier), nothing sent', async () => {
    await seedCouple('ist', { streak: streakOf(3) }); // no day doc seeded
    await seedUser(UID_A);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary).toEqual({
      checked: 0,
      sent: 0,
      skippedNoToken: 0,
      skippedNoDay: 1,
      suppressedQuiet: 0,
      failed: 0,
    });
    expect(port.sent).toHaveLength(0);
  });

  it('a recipient with no fcm token is a loud skippedNoToken, nothing sent', async () => {
    await seedCouple('ist', { streak: streakOf(3) });
    await seedDay('ist');
    await seedAnswer('ist', UID_A); // only UID_B is a recipient
    await seedUser(UID_B, { fcmTokens: [] }); // no token to send to

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(1);
    expect(summary.sent).toBe(0);
    expect(summary.skippedNoToken).toBe(1);
    expect(port.sent).toHaveLength(0);
  });

  it('a corrupt couple (malformed memberUids) is a per-couple failed skip, never a throw', async () => {
    await seedCouple('ist', { streak: streakOf(3), memberUids: 'not-an-array' });
    await seedDay('ist');

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    // Eligible (streak > 0, day unrevealed) → checked; recipient resolution then
    // throws on the corrupt members and is counted as a failed skip.
    expect(summary.checked).toBe(1);
    expect(summary.failed).toBe(1);
    expect(summary.sent).toBe(0);
    expect(port.sent).toHaveLength(0);
  });
});

describe('deliverAtRiskPush — delivery branches & the defense-in-depth quiet guard', () => {
  it('suppresses inside couple-local quiet hours even when called directly (defense in depth)', async () => {
    await seedUser(UID_A);
    const port = new FakeMessagingPort();

    const outcome = await deliverAtRiskPush(db, port, UID_A, 3, TZ, QUIET_AT);

    expect(outcome.status).toBe('suppressed-quiet-hours');
    expect(outcome.suppressedQuiet).toBe(1);
    expect(outcome.sent).toBe(0);
    expect(port.sent).toHaveLength(0);
  });

  it('a discreet (AR) recipient gets the generic payload — no streak digits leak to the lock screen', async () => {
    await seedUser(UID_A, { contentLanguage: 'ar' });
    const port = new FakeMessagingPort();

    const outcome = await deliverAtRiskPush(db, port, UID_A, 7, TZ, AT);

    const expected = composePush({ kind: 'streakAtRisk', language: 'ar', discreet: true, streakCount: 7 });
    expect(outcome.status).toBe('sent');
    expect(port.sent).toEqual([{ token: `tok-${UID_A}`, title: expected.title, body: expected.body }]);
    expect(port.sent[0].body).not.toContain('7');
  });

  it('a recipient with no user doc at all collapses to a no-tokens skip', async () => {
    // No users/uid-a doc seeded → fcmTokensOf(undefined) is [], same skip as an
    // empty fcmTokens field (ADR-012: nothing to send to).
    const outcome = await deliverAtRiskPush(db, new FakeMessagingPort(), UID_A, 3, TZ, AT);

    expect(outcome.status).toBe('no-tokens');
    expect(outcome.skippedNoToken).toBe(1);
    expect(outcome.sent).toBe(0);
  });

  it('every token failing is a swallowed send-failed, never a throw', async () => {
    await seedUser(UID_A);
    const port = new FakeMessagingPort();
    port.failOn(`tok-${UID_A}`);

    const outcome = await deliverAtRiskPush(db, port, UID_A, 3, TZ, AT);

    expect(outcome.status).toBe('send-failed');
    expect(outcome.failed).toBe(1);
    expect(outcome.sent).toBe(0);
  });

  it('a corrupt recipient uid path is a swallowed send-failed, never a throw', async () => {
    const outcome = await deliverAtRiskPush(db, new FakeMessagingPort(), '', 3, TZ, AT);

    expect(outcome.status).toBe('send-failed');
    expect(outcome.failed).toBe(1);
  });
});
