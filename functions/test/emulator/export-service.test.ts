// The M6.2 self-serve export against the firestore emulator (ADR-019 Decision 5,
// Test commitments). Positive-per-section coverage AND the negative sweep: the
// serialized document must contain NO occurrence of B's uid, B's answer text, or
// B's daily-lane counts — for a revealed day AND a pre-reveal day (the D5
// B-minimization decision). Seeded on the NO_TRIGGER project (it seeds answer
// docs); the Auth lookup + clock are injected so no auth emulator is needed and
// generatedAt is deterministic.
import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import type { ExportDeps } from '../../src/data-rights/export-service';
import { buildExportDocument } from '../../src/data-rights/export-service';
import { clearNoTriggerFirestore, noTriggerFirestore } from '../support/admin';

const db = noTriggerFirestore();

const A = 'exp-a';
const B = 'exp-b';
const CID = 'exp-couple';
const DAY_REVEALED = '20260709';
const DAY_PREREVEAL = '20260710';

const B_REVEALED_TEXT = 'BBBB_SECRET_REVEALED_ANSWER';
const B_PREREVEAL_TEXT = 'BBBB_SECRET_PREREVEAL_ANSWER';
const B_DAILY_COUNT = 4242;
const A_DAILY_COUNT = 7;

const FIXED_NOW = 1_700_000_000_000;
const deps: ExportDeps = {
  now: () => FIXED_NOW,
  authLookup: async () => ({ displayName: 'Aytek', email: 'a@example.com', photoURL: null }),
};

async function seedPaired(): Promise<void> {
  await db.collection('couples').doc(CID).set({
    memberUids: [A, B],
    timezone: 'Europe/Istanbul',
    createdAt: Timestamp.now(),
    streak: { count: 4, lastMutualDate: '20260709', graceTokens: 0 },
  });
  // Revealed day: both answered, day.revealedAt set.
  await db.collection('couples').doc(CID).collection('days').doc(DAY_REVEALED).set({
    questionId: 'solo_tr_001', packId: 'solo_tr', packVersion: 1, assignedAt: Timestamp.now(), revealedAt: Timestamp.now(),
  });
  await db.collection('couples').doc(CID).collection('days').doc(DAY_REVEALED).collection('answers').doc(A).set({ questionId: 'solo_tr_001', text: 'A revealed answer', answeredAt: Timestamp.now() });
  await db.collection('couples').doc(CID).collection('days').doc(DAY_REVEALED).collection('answers').doc(B).set({ questionId: 'solo_tr_001', text: B_REVEALED_TEXT, answeredAt: Timestamp.now() });
  // Pre-reveal day: both answered, NO revealedAt.
  await db.collection('couples').doc(CID).collection('days').doc(DAY_PREREVEAL).set({ questionId: 'solo_tr_002', packId: 'solo_tr', packVersion: 1, assignedAt: Timestamp.now() });
  await db.collection('couples').doc(CID).collection('days').doc(DAY_PREREVEAL).collection('answers').doc(A).set({ questionId: 'solo_tr_002', text: 'A prereveal answer', answeredAt: Timestamp.now() });
  await db.collection('couples').doc(CID).collection('days').doc(DAY_PREREVEAL).collection('answers').doc(B).set({ questionId: 'solo_tr_002', text: B_PREREVEAL_TEXT, answeredAt: Timestamp.now() });

  await db.collection('subscriptions').doc(CID).set({
    entitled: true, productId: 'premium_annual', periodType: 'NORMAL', expiresAtMs: Date.now() + 10_000_000_000, willRenew: true, store: 'APP_STORE', environment: 'PRODUCTION',
    lanes: { [A]: { entitled: true, productId: 'premium_annual', lastEventId: 'evt-a' }, [B]: { entitled: true, productId: 'premium_annual', lastEventId: 'evt-b' } },
    updatedAt: Timestamp.now(),
  });
  await db.collection('coachUsage').doc(CID).set({ monthly: { monthKey: '202607', count: 11 }, updatedAt: Timestamp.now() });
  await db.collection('coachUsage').doc(CID).collection('daily').doc(A).set({ dayKey: DAY_PREREVEAL, count: A_DAILY_COUNT, updatedAt: Timestamp.now() });
  await db.collection('coachUsage').doc(CID).collection('daily').doc(B).set({ dayKey: DAY_PREREVEAL, count: B_DAILY_COUNT, updatedAt: Timestamp.now() });

  await db.collection('invites').doc('AAAA2222').set({ creatorUid: A, status: 'pending', expiresAt: Timestamp.fromMillis(Date.now() + 60_000), createdAt: Timestamp.now() });
  await db.collection('invites').doc('BBBB3333').set({ creatorUid: B, joinerUid: A, status: 'joined', coupleId: CID, joinedAt: Timestamp.now(), createdAt: Timestamp.now() });
  await db.collection('invites').doc('CCCC4444').set({ creatorUid: B, status: 'pending', expiresAt: Timestamp.fromMillis(Date.now() + 60_000), createdAt: Timestamp.now() });

  await db.collection('users').doc(A).set({ status: 'married', contentLanguage: 'tr', register: 'respectful', coupleId: CID, notificationPrivacy: 'discreet', createdAt: Timestamp.now() });
  await db.collection('users').doc(B).set({ status: 'married', contentLanguage: 'ar', register: 'respectful', coupleId: CID, createdAt: Timestamp.now() });
  await db.collection('users').doc(A).collection('soloAnswers').doc('20260701').set({ questionId: 'solo_tr_9', text: 'A solo reflection', answeredAt: Timestamp.now() });
  await db.collection('users').doc(B).collection('soloAnswers').doc('20260701').set({ questionId: 'solo_tr_9', text: 'B solo reflection', answeredAt: Timestamp.now() });
}

beforeEach(async () => {
  await clearNoTriggerFirestore();
});

describe('buildExportDocument — envelope + positive per section', () => {
  it('produces a formatVersion-1 envelope with every A-authored section present', async () => {
    await seedPaired();
    const result = await buildExportDocument(db, A, deps);
    expect(result.kind).toBe('ok');
    if (result.kind !== 'ok') return;
    const doc = result.document;

    expect(doc.formatVersion).toBe(1);
    expect(doc.uid).toBe(A);
    expect(doc.generatedAt).toBe(new Date(FIXED_NOW).toISOString());

    // profile: client fields + Auth record + notificationPrivacy.
    expect(doc.data.profile.status).toBe('married');
    expect(doc.data.profile.contentLanguage).toBe('tr');
    expect(doc.data.profile.displayName).toBe('Aytek');
    expect(doc.data.profile.email).toBe('a@example.com');
    expect(doc.data.profile.notificationPrivacy).toBe('discreet');

    // soloAnswers, couple context, A's couple answers, coach lane, subscription, invites.
    expect(doc.data.soloAnswers.map((s) => s.text)).toContain('A solo reflection');
    expect(doc.data.coupleContext?.coupleId).toBe(CID);
    expect(doc.data.coupleContext?.coachMonthlyCount).toBe(11);
    expect(doc.data.coupleAnswers.map((a) => a.text).sort()).toEqual(['A prereveal answer', 'A revealed answer']);
    const revealed = doc.data.coupleAnswers.find((a) => a.dayKey === DAY_REVEALED);
    const prereveal = doc.data.coupleAnswers.find((a) => a.dayKey === DAY_PREREVEAL);
    expect(revealed?.revealed).toBe(true);
    expect(prereveal?.revealed).toBe(false);
    expect(doc.data.coachUsage.daily?.count).toBe(A_DAILY_COUNT);
    expect(doc.data.subscription?.summary.entitled).toBe(true);
    expect(doc.data.subscription?.lane?.lastEventId).toBe('evt-a');
    expect(doc.data.invites.map((i) => i.code).sort()).toEqual(['AAAA2222', 'BBBB3333']);
  });

  it('the negative sweep: NO B uid, B answer text, or B daily-lane count anywhere', async () => {
    await seedPaired();
    const result = await buildExportDocument(db, A, deps);
    expect(result.kind).toBe('ok');
    if (result.kind !== 'ok') return;
    const serialized = JSON.stringify(result.document);

    expect(serialized).not.toContain(B); // B's uid, incl. as a lane key / member / counterpart
    expect(serialized).not.toContain(B_REVEALED_TEXT); // revealed-day B-absence
    expect(serialized).not.toContain(B_PREREVEAL_TEXT); // pre-reveal-day B-absence
    expect(serialized).not.toContain(String(B_DAILY_COUNT)); // B's daily-lane count
    expect(serialized).not.toContain('evt-b'); // B's subscription lane
    expect(serialized).not.toContain('memberUids');
  });
});

describe('buildExportDocument — unpaired, free tier, missing profile', () => {
  it('exports an unpaired user with no couple sections', async () => {
    await db.collection('users').doc(A).set({ status: 'dating', contentLanguage: 'tr', register: 'playful', createdAt: Timestamp.now() });
    await db.collection('users').doc(A).collection('soloAnswers').doc('20260701').set({ questionId: 'q', text: 'solo only', answeredAt: Timestamp.now() });
    await db.collection('invites').doc('AAAA2222').set({ creatorUid: A, status: 'pending', expiresAt: Timestamp.fromMillis(Date.now() + 60_000), createdAt: Timestamp.now() });

    const result = await buildExportDocument(db, A, deps);
    expect(result.kind).toBe('ok');
    if (result.kind !== 'ok') return;
    expect(result.document.data.coupleContext).toBeNull();
    expect(result.document.data.coupleAnswers).toEqual([]);
    expect(result.document.data.subscription).toBeNull();
    expect(result.document.data.coachUsage.daily).toBeNull();
    expect(result.document.data.soloAnswers).toHaveLength(1);
    expect(result.document.data.invites).toHaveLength(1);
  });

  it('a free-tier (no subscription doc) paired caller still exports — no premium gate', async () => {
    await db.collection('couples').doc(CID).set({ memberUids: [A, B], timezone: 'Europe/Istanbul', createdAt: Timestamp.now() });
    await db.collection('users').doc(A).set({ status: 'married', contentLanguage: 'tr', register: 'respectful', coupleId: CID, createdAt: Timestamp.now() });

    const result = await buildExportDocument(db, A, deps);
    expect(result.kind).toBe('ok');
    if (result.kind !== 'ok') return;
    expect(result.document.data.coupleContext?.coupleId).toBe(CID);
    expect(result.document.data.subscription).toBeNull(); // absent doc = free tier
  });

  it('a missing requester profile is a typed profile-missing, no reads leaked', async () => {
    const result = await buildExportDocument(db, 'nobody', deps);
    expect(result).toEqual({ kind: 'profile-missing' });
  });
});
