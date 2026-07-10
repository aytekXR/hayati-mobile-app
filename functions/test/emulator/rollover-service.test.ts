// M3.2 rollover service against the firestore emulator (docs/resume-prompt.md
// Session 012, ADR-011): create-if-absent day assignment (idempotent, never
// reassigns), history-aware no-repeat selection, the timezone-bucketed sweep
// (a couple gets its new day at ITS local midnight), and the per-couple error
// boundary (a poisoned couple is a logged skip, never a failed run).
import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import type { Question, QuestionPack } from '../../src/rollover/pack-loader';
import { UnknownPackError } from '../../src/rollover/pack-loader';
import {
  DEFAULT_PACK_ID,
  type PackLoader,
  assignDayQuestion,
  isAlreadyExists,
  runQuestionRollover,
} from '../../src/rollover/rollover-service';
import { adminFirestore, clearFirestoreData } from '../support/admin';

const db = adminFirestore();
const couples = db.collection('couples');

// 2026-07-10T02:00:00Z: already 2026-07-10 in Istanbul (05:00, +03) but still
// 2026-07-09 in New York (22:00, EDT) — the two-zone acceptance instant.
const AT = new Date('2026-07-10T02:00:00Z');
const ISTANBUL_KEY = '20260710';
const NEW_YORK_KEY = '20260709';

function q(id: string, seasonalWindow?: string): Question {
  return { id, category: 'deep', depth: 2, text: `t-${id}`, seasonalWindow };
}

const TINY_PACK: QuestionPack = {
  packId: 'tiny_tr',
  version: 3,
  locale: 'tr',
  register: 'neutral',
  questions: [q('t1'), q('t2'), q('t3')],
};

const SEASONAL_ONLY_PACK: QuestionPack = {
  packId: 'seasonal_tr',
  version: 1,
  locale: 'tr',
  register: 'neutral',
  questions: [q('r1', 'ramadan')],
};

const loadTestPack: PackLoader = (packId) => {
  const pack = { tiny_tr: TINY_PACK, seasonal_tr: SEASONAL_ONLY_PACK }[packId];
  if (pack === undefined) {
    throw new UnknownPackError(packId, '<test packs>');
  }
  return pack;
};

/** Seeds a couple doc; `timezone: null` omits the field entirely. */
function seedCouple(
  coupleId: string,
  fields: { timezone?: string | null; packConfig?: unknown } = {},
): Promise<FirebaseFirestore.WriteResult> {
  const timezone = 'timezone' in fields ? fields.timezone : 'Europe/Istanbul';
  return couples.doc(coupleId).set({
    memberUids: ['uid-a', 'uid-b'],
    createdAt: Timestamp.now(),
    ...(timezone == null ? {} : { timezone }),
    ...('packConfig' in fields ? { packConfig: fields.packConfig } : {}),
  });
}

function dayDoc(coupleId: string, dayKey: string) {
  return couples.doc(coupleId).collection('days').doc(dayKey).get();
}

beforeEach(async () => {
  await clearFirestoreData();
});

describe('assignDayQuestion', () => {
  it('creates the day doc with the exact minimal field surface', async () => {
    await seedCouple('c1');
    const status = await assignDayQuestion(db, 'c1', ISTANBUL_KEY, 'tiny_tr', loadTestPack);

    expect(status).toBe('created');
    const doc = await dayDoc('c1', ISTANBUL_KEY);
    expect(doc.exists).toBe(true);
    const data = doc.data()!;
    expect(Object.keys(data).sort()).toEqual(['assignedAt', 'packId', 'packVersion', 'questionId']);
    expect(data.questionId).toBe('t1');
    expect(data.packId).toBe('tiny_tr');
    expect(data.packVersion).toBe(3);
    expect(data.assignedAt).toBeInstanceOf(Timestamp);
  });

  it('is idempotent: a re-run reports exists and leaves the doc byte-identical', async () => {
    await seedCouple('c1');
    await assignDayQuestion(db, 'c1', ISTANBUL_KEY, 'tiny_tr', loadTestPack);
    const first = (await dayDoc('c1', ISTANBUL_KEY)).data()!;

    const status = await assignDayQuestion(db, 'c1', ISTANBUL_KEY, 'tiny_tr', loadTestPack);
    expect(status).toBe('exists');
    const second = (await dayDoc('c1', ISTANBUL_KEY)).data()!;
    expect(second).toEqual(first);
  });

  it('never reassigns an existing day doc, even one carrying a different question', async () => {
    await seedCouple('c1');
    await couples.doc('c1').collection('days').doc(ISTANBUL_KEY).set({
      questionId: 'handwritten',
      packId: 'tiny_tr',
      packVersion: 2,
      assignedAt: Timestamp.now(),
    });

    const status = await assignDayQuestion(db, 'c1', ISTANBUL_KEY, 'tiny_tr', loadTestPack);
    expect(status).toBe('exists');
    expect((await dayDoc('c1', ISTANBUL_KEY)).data()!.questionId).toBe('handwritten');
  });

  it('walks the pack with no repeats across days, then recycles deterministically', async () => {
    await seedCouple('c1');
    const keys = ['20260710', '20260711', '20260712', '20260713', '20260714'];
    const assigned: string[] = [];
    for (const key of keys) {
      await assignDayQuestion(db, 'c1', key, 'tiny_tr', loadTestPack);
      assigned.push((await dayDoc('c1', key)).data()!.questionId as string);
    }
    // 3-question pack: unseen-first in pack order, then min-count recycle.
    expect(assigned).toEqual(['t1', 't2', 't3', 't1', 't2']);
  });

  it('treats losing the create race as a benign exists (ALREADY_EXISTS swallowed)', async () => {
    await seedCouple('c1');
    // The loader fires AFTER the existence check — committing today's doc
    // here simulates a concurrent sweep winning the race mid-flight.
    const racingLoader: PackLoader = async (packId) => {
      await couples.doc('c1').collection('days').doc(ISTANBUL_KEY).set({
        questionId: 't1',
        packId: 'tiny_tr',
        packVersion: 3,
        assignedAt: Timestamp.now(),
      });
      return loadTestPack(packId);
    };

    const status = await assignDayQuestion(db, 'c1', ISTANBUL_KEY, 'tiny_tr', racingLoader);
    expect(status).toBe('exists');
    expect((await dayDoc('c1', ISTANBUL_KEY)).data()!.questionId).toBe('t1');
  });

  it('rethrows non-ALREADY_EXISTS create failures', async () => {
    await seedCouple('c1');
    // Synthetic pack with an undefined version: the admin SDK rejects the
    // write client-side (undefined is not a Firestore value) — an error that
    // must escape, not be swallowed as a benign race.
    const brokenLoader: PackLoader = () => ({
      ...TINY_PACK,
      version: undefined as unknown as number,
    });
    await expect(
      assignDayQuestion(db, 'c1', ISTANBUL_KEY, 'tiny_tr', brokenLoader),
    ).rejects.toThrow(/undefined/i);
    expect((await dayDoc('c1', ISTANBUL_KEY)).exists).toBe(false);
  });

  it('ignores day docs without a string questionId when building history', async () => {
    await seedCouple('c1');
    await couples.doc('c1').collection('days').doc('20260709').set({
      questionId: 't1',
      packId: 'tiny_tr',
      packVersion: 3,
      assignedAt: Timestamp.now(),
    });
    // A hand-edited/foreign-shape doc must not corrupt selection.
    await couples.doc('c1').collection('days').doc('20260708').set({ junk: true });

    await assignDayQuestion(db, 'c1', ISTANBUL_KEY, 'tiny_tr', loadTestPack);
    expect((await dayDoc('c1', ISTANBUL_KEY)).data()!.questionId).toBe('t2');
  });
});

describe('isAlreadyExists', () => {
  it('matches only the numeric gRPC ALREADY_EXISTS code', () => {
    expect(isAlreadyExists({ code: 6 })).toBe(true);
    expect(isAlreadyExists({ code: 7 })).toBe(false);
    expect(isAlreadyExists({ code: 'already-exists' })).toBe(false);
    expect(isAlreadyExists(new Error('already exists'))).toBe(false);
    expect(isAlreadyExists(undefined)).toBe(false);
  });
});

describe('runQuestionRollover', () => {
  it('assigns each couple its day in ITS OWN local calendar date (timezone buckets)', async () => {
    await seedCouple('ist', { packConfig: { packId: 'tiny_tr' } });
    await seedCouple('nyc', { timezone: 'America/New_York', packConfig: { packId: 'tiny_tr' } });

    const summary = await runQuestionRollover(db, AT, loadTestPack);

    expect(summary).toEqual({
      assigned: 2,
      existing: 0,
      failed: 0,
      failedCoupleIds: [],
      buckets: 2,
    });
    expect((await dayDoc('ist', ISTANBUL_KEY)).exists).toBe(true);
    expect((await dayDoc('ist', NEW_YORK_KEY)).exists).toBe(false);
    expect((await dayDoc('nyc', NEW_YORK_KEY)).exists).toBe(true);
    expect((await dayDoc('nyc', ISTANBUL_KEY)).exists).toBe(false);
  });

  it('is idempotent at sweep level: the second run changes nothing', async () => {
    await seedCouple('ist', { packConfig: { packId: 'tiny_tr' } });
    await runQuestionRollover(db, AT, loadTestPack);
    const first = (await dayDoc('ist', ISTANBUL_KEY)).data()!;

    const summary = await runQuestionRollover(db, AT, loadTestPack);
    expect(summary.assigned).toBe(0);
    expect(summary.existing).toBe(1);
    expect((await dayDoc('ist', ISTANBUL_KEY)).data()).toEqual(first);
  });

  it('falls back to DEFAULT_PACK_ID for couples without packConfig (bundled solo_tr)', async () => {
    await seedCouple('ist');

    // Default loader on purpose: proves the lib/content/packs bundle serves
    // the sweep end-to-end (build ran before this suite).
    const summary = await runQuestionRollover(db, AT);

    expect(summary.assigned).toBe(1);
    const data = (await dayDoc('ist', ISTANBUL_KEY)).data()!;
    expect(data.packId).toBe(DEFAULT_PACK_ID);
    expect(data.questionId).toBe('solo_tr_001');
  });

  it('skips a malformed packConfig loudly without failing the run or writing a doc', async () => {
    await seedCouple('bad', { packConfig: {} });
    await seedCouple('good', { packConfig: { packId: 'tiny_tr' } });

    const summary = await runQuestionRollover(db, AT, loadTestPack);

    expect(summary.assigned).toBe(1);
    expect(summary.failed).toBe(1);
    expect(summary.failedCoupleIds).toEqual(['bad']);
    expect((await couples.doc('bad').collection('days').get()).size).toBe(0);
    expect((await dayDoc('good', ISTANBUL_KEY)).exists).toBe(true);
  });

  it('skips an unknown packId as a per-couple failure', async () => {
    await seedCouple('bad', { packConfig: { packId: 'no_such_pack' } });
    const summary = await runQuestionRollover(db, AT, loadTestPack);
    expect(summary.failed).toBe(1);
    expect(summary.failedCoupleIds).toEqual(['bad']);
  });

  it('skips couples with a missing or non-IANA timezone as per-couple failures', async () => {
    await seedCouple('no-tz', { timezone: null });
    await seedCouple('bad-tz', { timezone: 'Not/AZone' });
    await seedCouple('good', { packConfig: { packId: 'tiny_tr' } });

    const summary = await runQuestionRollover(db, AT, loadTestPack);

    expect(summary.assigned).toBe(1);
    expect(summary.failed).toBe(2);
    expect(summary.failedCoupleIds.sort()).toEqual(['bad-tz', 'no-tz']);
  });

  it('skips a couple whose pack has no evergreen question', async () => {
    await seedCouple('seasonal', { packConfig: { packId: 'seasonal_tr' } });
    const summary = await runQuestionRollover(db, AT, loadTestPack);
    expect(summary.failed).toBe(1);
    expect((await couples.doc('seasonal').collection('days').get()).size).toBe(0);
  });

  it('handles an empty couples collection as a clean no-op', async () => {
    const summary = await runQuestionRollover(db, AT, loadTestPack);
    expect(summary).toEqual({
      assigned: 0,
      existing: 0,
      failed: 0,
      failedCoupleIds: [],
      buckets: 0,
    });
  });
});
