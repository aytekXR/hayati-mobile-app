// The unanswered-day nudge against the firestore emulator (ADR-012 D3, RE-POINTED
// by ADR-042 D4). Proven at the SERVICE level (the M3.2 pattern): the hour gate
// (once per zone per day, sub-hour zones included), the eligibility rule,
// non-answerer recipient selection, and the best-effort send policy behind the
// injected port.
//
// ⚠️ ADR-042 D4 changed two things this suite used to pin, on purpose:
//   * the hour moved 20 → 16, because the founder asked for 16:00 — and ADR-045
//     (2026-08-10) moved it again, 16 → 22, for "at 10:00 PM, if the question
//     still hasn't been answered". 22 was the FIRST QUIET hour before that
//     change, so ADR-045 moved the quiet window to 23:00–08:00 in the same diff;
//     without that, every nudge would have been swallowed by the defense-in-depth
//     guard and tallied in `suppressedQuiet` — deployed, logged, and silent;
//   * the `streak.count > 0` gate is GONE, because the nudge now protects a
//     RELATIONSHIP rather than a streak and must reach couples who have neither.
// The tests that asserted the old rules were not relaxed — they were INVERTED to
// assert the new ones, so the zero-streak case is still covered, just with the
// opposite expectation.
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
import { isQuietLocalHour } from '../../src/notifications/local-hour';
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

// 2026-07-10T19:00:00Z: Istanbul (+03) reads 22:00 → the nudge fires;
// New York (EDT −04) reads 15:00 at the SAME instant → it does not.
const AT = new Date('2026-07-10T19:00:00Z');
// Asia/Kathmandu is +05:45: 16:30Z reads 22:15 → the sub-hour zone catches its
// hour-22 sweep on the same run its local clock crosses 22:xx.
const KTM_AT = new Date('2026-07-10T16:30:00Z');
// Istanbul 23:00 — inside the 23:00–08:00 quiet window (defense-in-depth check),
// and now exactly ONE HOUR after the nudge: the tightest possible proof that the
// window and AT_RISK_LOCAL_HOUR did not drift into each other (ADR-045).
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

describe('runStreakAtRisk — hour-16 gate (ADR-042 D4)', () => {
  it('AT_RISK_LOCAL_HOUR is 22 — the hour the founder asked for (ADR-045)', () => {
    expect(AT_RISK_LOCAL_HOUR).toBe(22);
  });

  // ⚠️ THE coupling this suite now owns. 22 used to be the first QUIET hour; the
  // window moved to 23 in the same change so the nudge could exist at all. Move
  // either constant by one, in either direction, and the feature dies silently
  // while every unrelated test stays green — precisely how a push feature fails
  // without anyone noticing.
  it('hour 22 is NOT quiet, and 23 IS — the nudge sits on the LAST legal hour', () => {
    expect(isQuietLocalHour(AT_RISK_LOCAL_HOUR)).toBe(false);
    expect(isQuietLocalHour(AT_RISK_LOCAL_HOUR + 1)).toBe(true);
  });

  it('fires ONLY for the bucket at couple-local hour 16; a same-instant off-16 zone and a corrupt zone are untouched', async () => {
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

  it('a sub-hour-offset zone (Asia/Kathmandu +05:45) fires at its 16:45 sweep', async () => {
    await seedCouple('ktm', { timezone: 'Asia/Kathmandu', streak: streakOf(4) });
    await seedDay('ktm');
    await seedUser(UID_A);
    await seedUser(UID_B);
    const buckets = await bucketCouplesByTimezone(db);

    // At AT (19:00Z) Kathmandu is 00:45 next day (hour 0) → nothing.
    const offSummary = await runStreakAtRisk(db, AT, new FakeMessagingPort(), buckets);
    expect(offSummary.checked).toBe(0);
    expect(offSummary.sent).toBe(0);

    // At KTM_AT (16:30Z) Kathmandu is 22:15 (hour 22) → fires.
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

  // ADR-042 D4 INVERTED these two. They used to assert that a couple with no
  // streak gets nothing — "nothing to lose". That was the streak feature's rule.
  // The founder's nudge protects the relationship, so a couple with no streak is
  // precisely who it is for: week-one couples, and every couple that ever broke
  // one. The tests were not deleted when the rule flipped; they were flipped, so
  // the case stays covered with the opposite expectation.
  it('a zero-count streak is STILL nudged — the nudge protects the relationship, not the counter', async () => {
    await seedCouple('ist', { streak: { count: 0, lastMutualDate: null, graceTokens: 1 } });
    await seedDay('ist');
    await seedUser(UID_A);
    await seedUser(UID_B);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(1);
    expect(summary.sent).toBe(2);
  });

  it('an absent streak field is STILL nudged (a week-one couple has no streak field at all)', async () => {
    await seedCouple('ist'); // no streak field
    await seedDay('ist');
    await seedUser(UID_A);
    await seedUser(UID_B);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    const summary = await runStreakAtRisk(db, AT, port, buckets);

    expect(summary.checked).toBe(1);
    expect(summary.sent).toBe(2);
  });

  // The copy consequence of dropping the gate: a streakless couple must not be
  // told their streak is alive. composePush owns this; asserted here end-to-end
  // because the wrong copy is the failure a user would actually see.
  it('a streakless couple gets the relationship copy, never a streak claim', async () => {
    await seedCouple('ist'); // no streak
    await seedDay('ist');
    await seedUser(UID_A);
    await seedUser(UID_B);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    await runStreakAtRisk(db, AT, port, buckets);

    expect(port.sent).not.toHaveLength(0);
    for (const message of port.sent) {
      expect(message.body.toLowerCase()).not.toContain('streak');
      expect(message.title.toLowerCase()).not.toContain('streak');
    }
  });

  it('a couple WITH a streak still gets the streak copy — nothing was lost', async () => {
    await seedCouple('ist', { streak: streakOf(7) });
    await seedDay('ist');
    await seedUser(UID_A);
    await seedUser(UID_B);

    const buckets = await bucketCouplesByTimezone(db);
    const port = new FakeMessagingPort();
    await runStreakAtRisk(db, AT, port, buckets);

    expect(port.sent[0].body).toContain('7');
  });

  it('NO day doc → a SEPARATE skippedNoDay skip (rollover failed earlier), nothing sent', async () => {
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
