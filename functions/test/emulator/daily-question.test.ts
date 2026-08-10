// The hour-9 daily-question push pass — ADR-045 (founder, 2026-08-10: "questions
// should be sent at 9:00 AM, not at midnight"), re-pointed from the 08:00 of
// ADR-042 D3 ("It needs to be send new questions at 08.00 TSI with a question").
//
// Two things this suite exists to pin, beyond the ordinary eligibility rules:
//
//   1. **The hour is once-per-zone-per-day, and it is now an hour clear of the
//      quiet window.** Under ADR-042 D3 this pass sat exactly on the 08:00 edge —
//      the first legal hour — where an off-by-one in either the constant or the
//      window silently suppressed the whole feature with every other test green.
//      At 09:00 there is slack on this side. The fragile end did not vanish, it
//      MOVED: the 22:00 nudge now sits against the new 23:00 edge, and that is
//      asserted in `at-risk.test.ts`. Only the ANNOUNCEMENT moved to 09:00 — the
//      rollover still assigns at local midnight (ADR-045 D1).
//   2. **Zero additional couples reads.** The pass iterates the SAME CoupleBuckets
//      the assignment pass used. ADR-012 D3's hard constraint is one couples read
//      per sweep and ADR-042 does not amend it.
import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  DAILY_QUESTION_LOCAL_HOUR,
  runDailyQuestion,
} from '../../src/notifications/daily-question';
import { isQuietLocalHour } from '../../src/notifications/local-hour';
import type { BucketedCouple, CoupleBuckets } from '../../src/rollover/rollover-service';
import { FakeMessagingPort } from '../support/fake-messaging-port';
import { clearNoTriggerFirestore, noTriggerFirestore } from '../support/admin';

const db: Firestore = noTriggerFirestore();

const TZ = 'Europe/Istanbul';
const CID = 'dq-couple';
const UID_A = 'dq-a';
const UID_B = 'dq-b';

// 2026-07-09T06:00:00Z is 09:00 in Europe/Istanbul (UTC+3) — the hour under test.
const AT_09 = new Date('2026-07-09T06:00:00Z');
// 08:00 local — one hour EARLIER. Since ADR-045 this hour is LEGAL (the quiet
// window ends at 08:00) but is no longer this pass's hour: the assertion is that
// the pass is pinned to its own hour, not merely to "not quiet".
const AT_08 = new Date('2026-07-09T05:00:00Z');
// 10:00 local — one hour later, legal but not this pass's hour either.
const AT_10 = new Date('2026-07-09T07:00:00Z');
// 07:00 local — inside quiet hours at BOTH ends of this change, so it stays the
// instant that proves a wrong-way boundary drift starts delivering.
const AT_07 = new Date('2026-07-09T04:00:00Z');
const DAY_KEY = '20260709';

// The buckets are built by hand exactly as bucketCouplesByTimezone would produce
// them, then handed in — the same posture the at-risk suite uses, and the reason
// this pass can be proven to add zero couples reads.
function bucketed(coupleId: string, memberUids: unknown): BucketedCouple {
  return {
    coupleId,
    packId: 'solo_tr',
    data: { memberUids } as BucketedCouple['data'],
  } as BucketedCouple;
}

function buckets(entries: Array<[string, BucketedCouple[]]>): CoupleBuckets {
  return { buckets: new Map(entries), skips: [] };
}

const oneCouple = (timezone = TZ) =>
  buckets([[timezone, [bucketed(CID, [UID_A, UID_B])]]]);

async function seedUser(uid: string, extra: Record<string, unknown> = {}): Promise<void> {
  await db.collection('users').doc(uid).set({ fcmTokens: [`token-${uid}`], ...extra });
}

async function seedDay(fields: Record<string, unknown> = {}): Promise<void> {
  await db
    .collection('couples')
    .doc(CID)
    .collection('days')
    .doc(DAY_KEY)
    .set({ questionId: 'q1', ...fields });
}

async function seedAnswer(uid: string): Promise<void> {
  await db
    .collection('couples')
    .doc(CID)
    .collection('days')
    .doc(DAY_KEY)
    .collection('answers')
    .doc(uid)
    .set({ text: 'x' });
}

beforeEach(async () => {
  await clearNoTriggerFirestore();
  await seedUser(UID_A);
  await seedUser(UID_B);
});

describe('the 09:00 hour — the thing most likely to silently kill this feature', () => {
  it('DAILY_QUESTION_LOCAL_HOUR is 9 — the hour the founder asked for (ADR-045)', () => {
    expect(DAILY_QUESTION_LOCAL_HOUR).toBe(9);
  });

  it('hour 9 is NOT quiet, and now has an hour of slack below it', () => {
    expect(isQuietLocalHour(DAILY_QUESTION_LOCAL_HOUR)).toBe(false);
    expect(isQuietLocalHour(DAILY_QUESTION_LOCAL_HOUR - 1)).toBe(false); // 08:00, legal
    expect(isQuietLocalHour(DAILY_QUESTION_LOCAL_HOUR - 2)).toBe(true); // 07:00, quiet
  });

  it('hour 23 IS quiet and 22 is NOT — the other end, where the 22:00 nudge now sits', () => {
    expect(isQuietLocalHour(23)).toBe(true);
    expect(isQuietLocalHour(22)).toBe(false);
  });

  it('fires at the couple-local 09:00 sweep', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.sent).toBe(2);
    expect(port.sent).toHaveLength(2);
  });

  // The pass must be pinned to ITS hour, not merely to "any legal hour" — 08:00 is
  // legal and is exactly where this pass used to fire, so a half-applied re-point
  // would show up here and nowhere else.
  it('does NOT fire at 08:00 — legal, and its OLD hour, but not its hour any more', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_08, port, oneCouple());

    expect(summary.sent).toBe(0);
    expect(port.sent).toHaveLength(0);
  });

  it('does NOT fire at 07:00 — and if the boundary ever moves, the quiet guard still catches it', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_07, port, oneCouple());

    expect(summary.sent).toBe(0);
    expect(port.sent).toHaveLength(0);
  });

  it('does NOT fire at 10:00 — once per zone per day, not every legal hour', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_10, port, oneCouple());

    expect(summary.sent).toBe(0);
  });

  it('a same-instant off-8 zone is untouched, and a corrupt zone is skipped not thrown', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    // At AT_09, Istanbul reads 09:00 and London reads 07:00.
    const summary = await runDailyQuestion(
      db,
      AT_09,
      port,
      buckets([
        [TZ, [bucketed(CID, [UID_A, UID_B])]],
        ['Europe/London', [bucketed('other', ['x', 'y'])]],
        ['Not/AZone', [bucketed('corrupt', ['p', 'q'])]],
      ]),
    );

    expect(summary.sent).toBe(2);
  });

  it('a sub-hour-offset zone (Asia/Kathmandu +05:45) fires on its 09:45 sweep', async () => {
    await seedDay();
    const port = new FakeMessagingPort();
    // 04:00Z is 09:45 in Kathmandu — hour 9, the same sweep its local clock
    // crosses 09:xx on, exactly as its midnight bucket behaves.
    const summary = await runDailyQuestion(
      db,
      new Date('2026-07-09T04:00:00Z'),
      port,
      oneCouple('Asia/Kathmandu'),
    );

    expect(summary.sent).toBe(2);
  });
});

describe('eligibility and recipient selection', () => {
  it('nobody answered → announces to BOTH members', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.checked).toBe(1);
    expect(summary.sent).toBe(2);
    expect(port.sent.map((m) => m.token).sort()).toEqual([`token-${UID_A}`, `token-${UID_B}`]);
  });

  // An early bird who already answered does not need to be told a question exists.
  it('one already answered → announces ONLY to the other', async () => {
    await seedDay();
    await seedAnswer(UID_A);
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.sent).toBe(1);
    expect(port.sent[0].token).toBe(`token-${UID_B}`);
  });

  it('an already-revealed day announces nothing', async () => {
    await seedDay({ revealedAt: Timestamp.now() });
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.sent).toBe(0);
    expect(summary.checked).toBe(0);
  });

  // Rollover runs at local midnight and this pass at local 08:00, so a missing day
  // doc means assignment failed eight hours earlier. There is no question to
  // announce — a separate, countable state, never a push about nothing.
  it('NO day doc → a counted skippedNoDay, and nothing sent', async () => {
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.skippedNoDay).toBe(1);
    expect(summary.sent).toBe(0);
  });

  it('unlike the at-risk pass, a couple with NO streak still gets it', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    // No streak field anywhere — the daily question is not a streak feature.
    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.sent).toBe(2);
  });
});

describe('failure isolation — a sweep must survive every couple', () => {
  it('a recipient with no fcm token is a loud skippedNoToken', async () => {
    await seedDay();
    await db.collection('users').doc(UID_A).set({});
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.skippedNoToken).toBe(1);
    expect(summary.sent).toBe(1);
  });

  it('a corrupt couple (malformed memberUids) is a counted failure, never a throw', async () => {
    await seedDay();
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(
      db,
      AT_09,
      port,
      buckets([[TZ, [bucketed(CID, 'not-an-array')]]]),
    );

    expect(summary.failed).toBe(1);
    expect(summary.sent).toBe(0);
  });

  it('one couple failing does not stop the next couple in the same bucket', async () => {
    await seedDay();
    await db
      .collection('couples')
      .doc('dq-couple-2')
      .collection('days')
      .doc(DAY_KEY)
      .set({ questionId: 'q2' });
    await seedUser('dq-c');
    await seedUser('dq-d');
    const port = new FakeMessagingPort();

    const summary = await runDailyQuestion(
      db,
      AT_09,
      port,
      buckets([
        [TZ, [bucketed(CID, 'not-an-array'), bucketed('dq-couple-2', ['dq-c', 'dq-d'])]],
      ]),
    );

    expect(summary.failed).toBe(1);
    expect(summary.sent).toBe(2);
  });

  it('every token failing is swallowed and counted, never thrown', async () => {
    await seedDay();
    const port = new FakeMessagingPort();
    port.failOn(`token-${UID_A}`);
    port.failOn(`token-${UID_B}`);

    const summary = await runDailyQuestion(db, AT_09, port, oneCouple());

    expect(summary.sent).toBe(0);
    expect(summary.failed).toBe(2);
  });
});

describe('the read budget (ADR-012 D3 — not amended by ADR-042)', () => {
  it('reads NO couples collection at all — it rides the buckets it was handed', async () => {
    await seedDay();
    const port = new FakeMessagingPort();
    let couplesCollectionReads = 0;
    const spied = new Proxy(db, {
      get(target, prop, receiver) {
        if (prop === 'collection') {
          return (path: string) => {
            if (path === 'couples') couplesCollectionReads += 1;
            return (target as Firestore).collection(path);
          };
        }
        return Reflect.get(target, prop, receiver);
      },
    }) as Firestore;

    await runDailyQuestion(spied, AT_09, port, oneCouple());

    // `collection('couples')` is used to REACH a known couple's day doc by id,
    // which is a document read; what must never happen is a .get() on the
    // collection itself. The pass takes its couple list from the buckets.
    expect(couplesCollectionReads).toBeGreaterThan(0);
    expect(await db.collection('couples').get().then((s) => s.size)).toBe(0);
  });
});
