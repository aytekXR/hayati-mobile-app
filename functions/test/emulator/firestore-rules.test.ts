// Security-rules suite for the M2.1 invariants (architecture.md §3):
//   - users/{uid}: self-only, createdAt create-once & immutable, no client delete
//   - couples/{coupleId}: member-only read/update, memberUids frozen, no client create/delete
//   - invites/{code}: no client access at all (function-write-only; preview is
//     the M2.2 Function endpoint)
// plus MUTATION tests: each protecting clause is weakened in a copy of the
// rules and the previously-denied op must then SUCCEED — proving the suite
// goes red if someone comments the rule out (resume-prompt acceptance:
// "prove the net, don't just assert green").
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

const RULES_PATH = fileURLToPath(
  new URL('../../../firestore.rules', import.meta.url),
);
const rules = readFileSync(RULES_PATH, 'utf8');

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const CHARLIE = 'charlie-uid';

const profileData = {
  status: 'married',
  contentLanguage: 'tr',
  register: 'respectful',
};

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hayati-rules',
    firestore: { rules },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

afterAll(async () => {
  await env.cleanup();
});

/** Seeds documents with rules disabled (owner context). */
async function seed(path: string, data: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function seedAliceProfile(): Promise<void> {
  await seed(`users/${ALICE}`, {
    ...profileData,
    createdAt: Timestamp.now(),
  });
}

/** The valid consent-record shape the recordConsent callable stamps (ADR-023 D4). */
const consentField = () => ({
  version: 1,
  acceptedAt: Timestamp.now(),
  ageAttested: true,
});

/**
 * Seeds a profile carrying a valid consent record (owner context) — the ADR-023
 * D4a precondition on soloAnswer/couple-answer writes. Answer-writing tests use
 * this so the write exercises the shape guards, not the consent gate.
 */
async function seedConsentedProfile(uid: string): Promise<void> {
  await seed(`users/${uid}`, {
    ...profileData,
    consent: consentField(),
    createdAt: Timestamp.now(),
  });
}

/** A real-shaped couple: exactly what the M2.3 join Function writes. */
async function seedCouple(): Promise<void> {
  await seed('couples/couple-1', {
    memberUids: [ALICE, BOB],
    timezone: 'Europe/Istanbul',
    createdAt: Timestamp.now(),
  });
}

/** A couple that already carries a streak (post-first-mutual-day, M3.4). */
async function seedCoupleWithStreak(): Promise<void> {
  await seed('couples/couple-1', {
    memberUids: [ALICE, BOB],
    timezone: 'Europe/Istanbul',
    createdAt: Timestamp.now(),
    streak: { count: 3, lastMutualDate: '20260709', graceTokens: 1 },
  });
}

/** Seeds Alice already paired (users doc carries a coupleId), createdAt intact. */
async function seedPairedAliceProfile(): Promise<void> {
  await seed(`users/${ALICE}`, {
    ...profileData,
    coupleId: 'couple-1',
    createdAt: Timestamp.now(),
  });
}

describe('users/{uid}', () => {
  it('owner creates with server-stamped createdAt', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      setDoc(doc(alice, `users/${ALICE}`), {
        ...profileData,
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('create is denied without createdAt', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, `users/${ALICE}`), profileData));
  });

  it('create is denied with a client-clock createdAt', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, `users/${ALICE}`), {
        ...profileData,
        createdAt: Timestamp.fromMillis(1_000_000),
      }),
    );
  });

  it('only the owner writes their profile', async () => {
    const charlie = env.authenticatedContext(CHARLIE).firestore();
    await assertFails(
      setDoc(doc(charlie, `users/${ALICE}`), {
        ...profileData,
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('owner reads own profile; others and anonymous cannot', async () => {
    await seedAliceProfile();
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), `users/${ALICE}`)),
    );
    await assertFails(
      getDoc(
        doc(env.authenticatedContext(CHARLIE).firestore(), `users/${ALICE}`),
      ),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), `users/${ALICE}`)),
    );
  });

  it('merge update that omits createdAt passes (the app writes this shape)', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      setDoc(doc(alice, `users/${ALICE}`), { register: 'playful' }, { merge: true }),
    );
  });

  it('update may not move createdAt', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), {
        createdAt: Timestamp.fromMillis(42),
      }),
    );
  });

  it('update may not delete createdAt', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { createdAt: deleteField() }),
    );
  });

  it('clients never delete profiles (M6 cascade Function only)', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(deleteDoc(doc(alice, `users/${ALICE}`)));
  });

  // coupleId is authorization-meaningful (it keys couples/{coupleId} membership)
  // and is written ONLY by the M2.3 join Function — a client may never
  // introduce, change, or delete it (M2.3 freeze).
  it('create is denied when the client includes coupleId', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, `users/${ALICE}`), {
        ...profileData,
        createdAt: serverTimestamp(),
        coupleId: 'couple-x',
      }),
    );
  });

  // ADR-019 D3/D6: coupleEnded and notificationPrivacy are server-owned. The
  // update rule freezes them, but the freeze is only real if a client also
  // cannot MINT them on a fresh self-create (the exact shape of the coupleId
  // create block) — otherwise a fresh signup or a post-deletion token-window
  // re-create could plant them. Both create paths are denied.
  it('create is denied when the client includes coupleEnded (server-owned tombstone)', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, `users/${ALICE}`), {
        ...profileData,
        createdAt: serverTimestamp(),
        coupleEnded: { at: Timestamp.now() },
      }),
    );
  });

  it('create is denied when the client includes notificationPrivacy (server-owned override)', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, `users/${ALICE}`), {
        ...profileData,
        createdAt: serverTimestamp(),
        notificationPrivacy: 'discreet',
      }),
    );
  });

  it('a normal create carrying none of the server-owned fields still succeeds (positive control)', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      setDoc(doc(alice, `users/${ALICE}`), {
        ...profileData,
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('a merge update that sets coupleId is denied (the app-write shape)', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    // The app persists profile edits via setDoc(..., {merge:true}); a client
    // must not smuggle coupleId in through that same path.
    await assertFails(
      setDoc(
        doc(alice, `users/${ALICE}`),
        { register: 'playful', coupleId: 'couple-x' },
        { merge: true },
      ),
    );
  });

  it('an update changing an existing coupleId is denied', async () => {
    await seedPairedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { coupleId: 'couple-2' }),
    );
  });

  it('an update deleting coupleId is denied', async () => {
    await seedPairedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { coupleId: deleteField() }),
    );
  });

  it('a merge update that omits coupleId still passes when the doc has one', async () => {
    await seedPairedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    // Post-merge equality: get('coupleId', null) is unchanged on both sides, so
    // an ordinary profile edit by an already-paired owner is allowed.
    await assertSucceeds(
      setDoc(
        doc(alice, `users/${ALICE}`),
        { register: 'playful' },
        { merge: true },
      ),
    );
  });

  // ADR-019 Decision 6/3: notificationPrivacy (the discreet override) and
  // coupleEnded (the partner-notification tombstone) are server-owned and frozen
  // against clients, exactly like coupleId.
  it('a client may not mint notificationPrivacy on its own doc', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { notificationPrivacy: 'discreet' }),
    );
  });

  it('a client may not clear a server-set notificationPrivacy', async () => {
    await seed(`users/${ALICE}`, {
      ...profileData,
      notificationPrivacy: 'discreet',
      createdAt: Timestamp.now(),
    });
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { notificationPrivacy: deleteField() }),
    );
  });

  it('a client may not mint coupleEnded on its own doc', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { coupleEnded: { at: Timestamp.now() } }),
    );
  });

  it('a client may not clear a server-set coupleEnded', async () => {
    await seed(`users/${ALICE}`, {
      ...profileData,
      coupleEnded: { at: Timestamp.now() },
      createdAt: Timestamp.now(),
    });
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { coupleEnded: deleteField() }),
    );
  });

  it('ordinary own-doc edits still succeed alongside the new frozen fields (positive control)', async () => {
    await seed(`users/${ALICE}`, {
      ...profileData,
      notificationPrivacy: 'discreet',
      coupleEnded: { at: Timestamp.now() },
      createdAt: Timestamp.now(),
    });
    const alice = env.authenticatedContext(ALICE).firestore();
    // A register edit that leaves both frozen fields untouched (post-merge equal).
    await assertSucceeds(
      setDoc(doc(alice, `users/${ALICE}`), { register: 'playful' }, { merge: true }),
    );
  });

  // ADR-023 Decision 4: consent (the special-category consent record) is
  // server-owned — written ONLY by the recordConsent callable (admin SDK). Like
  // coupleId/coupleEnded/notificationPrivacy it needs a matched create-forbid +
  // update-freeze so a client can neither mint it at create nor mint/change/clear
  // it via update.
  it('create is denied when the client includes consent (server-owned)', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, `users/${ALICE}`), {
        ...profileData,
        createdAt: serverTimestamp(),
        consent: consentField(),
      }),
    );
  });

  it('a client may not mint consent on its own doc', async () => {
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { consent: consentField() }),
    );
  });

  it('a client may not clear a server-set consent', async () => {
    await seed(`users/${ALICE}`, {
      ...profileData,
      consent: consentField(),
      createdAt: Timestamp.now(),
    });
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, `users/${ALICE}`), { consent: deleteField() }),
    );
  });

  it('an ordinary own-doc edit succeeds alongside a server-set consent (positive control)', async () => {
    await seed(`users/${ALICE}`, {
      ...profileData,
      consent: consentField(),
      createdAt: Timestamp.now(),
    });
    const alice = env.authenticatedContext(ALICE).firestore();
    // A register edit that leaves consent untouched (post-merge equal) passes.
    await assertSucceeds(
      setDoc(doc(alice, `users/${ALICE}`), { register: 'playful' }, { merge: true }),
    );
  });
});

describe('users/{uid}/soloAnswers/{dayKey}', () => {
  const ANSWER_PATH = `users/${ALICE}/soloAnswers/20260710`;

  const validAnswer = () => ({
    questionId: 'solo_tr_003',
    text: 'Birlikte sakin bir sabah.',
    answeredAt: serverTimestamp(),
  });

  async function seedAliceAnswer(): Promise<void> {
    await seed(ANSWER_PATH, {
      questionId: 'solo_tr_003',
      text: 'Birlikte sakin bir sabah.',
      answeredAt: Timestamp.now(),
    });
  }

  // ADR-019 Decision 2: soloAnswer writes require the owner's profile to exist.
  // ADR-023 Decision 4a: they ALSO require the writer to carry a consent record.
  // Every Alice-based write test seeds her CONSENTED profile first; the orphan
  // test deliberately uses Bob (no profile) — denied by both exists() AND the
  // consent gate — and the D4a-negative test below overwrites Alice's profile
  // with a consentless one to isolate the consent predicate.
  beforeEach(async () => {
    await seedConsentedProfile(ALICE);
  });

  it('orphan write is denied when the owner has no profile (ADR-019 D2 token-window)', async () => {
    const bob = env.authenticatedContext(BOB).firestore();
    await assertFails(
      setDoc(doc(bob, `users/${BOB}/soloAnswers/20260710`), validAnswer()),
    );
  });

  // ADR-023 D4a: the consent predicate on the soloAnswers write, isolated.
  it('a consented owner writes their answer (D4a positive)', async () => {
    // beforeEach seeded ALICE with consent.
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, ANSWER_PATH), validAnswer()));
  });

  it('an owner with a profile but NO consent is denied (D4a negative)', async () => {
    // Overwrite the consented profile with a consentless one — exists() passes,
    // only the consent predicate should now deny.
    await seedAliceProfile();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, ANSWER_PATH), validAnswer()));
  });

  it('owner creates a server-stamped answer (the app write shape)', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, ANSWER_PATH), validAnswer()));
  });

  it('owner overwrites the day (answers stay editable all day)', async () => {
    await seedAliceAnswer();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      setDoc(doc(alice, ANSWER_PATH), {
        ...validAnswer(),
        text: 'İkinci düşünce.',
      }),
    );
  });

  it('owner reads own answers; others and anonymous cannot', async () => {
    await seedAliceAnswer();
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), ANSWER_PATH)),
    );
    await assertFails(
      getDoc(doc(env.authenticatedContext(CHARLIE).firestore(), ANSWER_PATH)),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), ANSWER_PATH)),
    );
  });

  it('only the owner writes their answers', async () => {
    const charlie = env.authenticatedContext(CHARLIE).firestore();
    await assertFails(setDoc(doc(charlie, ANSWER_PATH), validAnswer()));
  });

  it('create is denied with a client-clock answeredAt', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, ANSWER_PATH), {
        ...validAnswer(),
        answeredAt: Timestamp.fromMillis(1_000_000),
      }),
    );
  });

  it('create is denied without answeredAt', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, ANSWER_PATH), {
        questionId: 'solo_tr_003',
        text: 'Birlikte sakin bir sabah.',
      }),
    );
  });

  it('create is denied with fields outside the frozen surface', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, ANSWER_PATH), { ...validAnswer(), mood: 'great' }),
    );
  });

  it('create is denied with a missing questionId or empty/oversized text', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, ANSWER_PATH), {
        text: 'Birlikte sakin bir sabah.',
        answeredAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(alice, ANSWER_PATH), { ...validAnswer(), text: '' }),
    );
    await assertFails(
      setDoc(doc(alice, ANSWER_PATH), {
        ...validAnswer(),
        text: 'x'.repeat(2001),
      }),
    );
  });

  it('clients never delete answers (M6 cascade Function only)', async () => {
    await seedAliceAnswer();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(deleteDoc(doc(alice, ANSWER_PATH)));
  });
});

describe('couples/{coupleId}', () => {
  it('members read their couple; non-members and anonymous cannot', async () => {
    await seedCouple();
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), 'couples/couple-1')),
    );
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(BOB).firestore(), 'couples/couple-1')),
    );
    await assertFails(
      getDoc(
        doc(env.authenticatedContext(CHARLIE).firestore(), 'couples/couple-1'),
      ),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), 'couples/couple-1')),
    );
  });

  it('members update unfrozen fields (packConfig)', async () => {
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      updateDoc(doc(alice, 'couples/couple-1'), {
        packConfig: { packId: 'solo_tr' },
      }),
    );
  });

  it('timezone is frozen even for members (M3.3 — dayKey load-bearing)', async () => {
    // Since M3.3 the app computes the couple dayKey from the STORED timezone
    // (ADR-011); a member rewriting it to junk would brick both members'
    // daily loop AND the rollover (per-couple skip). Zone changes move
    // behind a Function, like memberUids.
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), { timezone: 'not-a-zone' }),
    );
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), { timezone: 'Asia/Riyadh' }),
    );
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), { timezone: deleteField() }),
    );
  });

  it('couple createdAt is frozen even for members', async () => {
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), {
        createdAt: Timestamp.fromMillis(42),
      }),
    );
  });

  // M3.4 (ADR-012): streak is written ONLY by the answerReveal trigger (admin
  // SDK), so a member may never introduce, change, or delete it — the freeze is
  // symmetric on absence (the field does not exist until the first mutual day).
  it('streak is frozen: a member cannot introduce it (M3.4 — admin trigger owns it)', async () => {
    await seedCouple(); // no streak yet
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), {
        streak: { count: 5, lastMutualDate: '20260710', graceTokens: 0 },
      }),
    );
  });

  it('streak is frozen: a member cannot change or delete an existing streak', async () => {
    await seedCoupleWithStreak();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), {
        streak: { count: 999, lastMutualDate: '20260709', graceTokens: 1 },
      }),
    );
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), { streak: deleteField() }),
    );
  });

  it('a member update that leaves streak untouched still passes (symmetric absence)', async () => {
    await seedCoupleWithStreak();
    const alice = env.authenticatedContext(ALICE).firestore();
    // Editing an unfrozen field: get('streak', null) is unchanged on both sides.
    await assertSucceeds(
      updateDoc(doc(alice, 'couples/couple-1'), { packConfig: { packId: 'solo_tr' } }),
    );
  });

  it('memberUids is frozen even for members', async () => {
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(alice, 'couples/couple-1'), {
        memberUids: [ALICE, CHARLIE],
      }),
    );
  });

  it('non-members cannot update', async () => {
    await seedCouple();
    const charlie = env.authenticatedContext(CHARLIE).firestore();
    await assertFails(
      updateDoc(doc(charlie, 'couples/couple-1'), { timezone: 'Asia/Riyadh' }),
    );
  });

  it('clients cannot create or delete couples (M2.3 join Function only)', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, 'couples/couple-2'), {
        memberUids: [ALICE, BOB],
        timezone: 'Europe/Istanbul',
      }),
    );
    await seedCouple();
    await assertFails(deleteDoc(doc(alice, 'couples/couple-1')));
  });
});

describe('couples/{coupleId}/days/{dayKey}', () => {
  const DAY_PATH = 'couples/couple-1/days/20260710';
  const dayData = () => ({
    questionId: 'solo_tr_001',
    packId: 'solo_tr',
    packVersion: 1,
    assignedAt: Timestamp.now(),
  });

  async function seedDay(): Promise<void> {
    await seedCouple();
    await seed(DAY_PATH, dayData());
  }

  it('members read the day doc; non-members and anonymous cannot', async () => {
    await seedDay();
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), DAY_PATH)),
    );
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(BOB).firestore(), DAY_PATH)),
    );
    await assertFails(
      getDoc(doc(env.authenticatedContext(CHARLIE).firestore(), DAY_PATH)),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), DAY_PATH)),
    );
  });

  it('a day doc under a missing parent couple is unreadable (fails closed)', async () => {
    // Orphaned day doc: parent couple never seeded. The membership get()
    // finds no couple, so the read must deny — corrupt state stays dark.
    await seed(DAY_PATH, dayData());
    await assertFails(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), DAY_PATH)),
    );
  });

  it('no client writes at all — not even members (function-only via admin SDK)', async () => {
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, DAY_PATH), dayData()));

    await seed(DAY_PATH, dayData());
    await assertFails(
      updateDoc(doc(alice, DAY_PATH), { questionId: 'solo_tr_007' }),
    );
    await assertFails(deleteDoc(doc(alice, DAY_PATH)));
  });
});

describe('couples/{coupleId}/days/{dayKey}/answers/{authorUid}', () => {
  const DAY_KEY = '20260710';
  const DAY_PATH = `couples/couple-1/days/${DAY_KEY}`;
  const answerPath = (uid: string) => `${DAY_PATH}/answers/${uid}`;

  /** The repository's exact write shape (full replace, server stamp). */
  const answerWrite = () => ({
    questionId: 'solo_tr_001',
    text: 'Bugün seninle gülümsedim.',
    answeredAt: serverTimestamp(),
  });

  async function seedCoupleDay(): Promise<void> {
    await seedCouple();
    await seed(DAY_PATH, {
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
    });
    // ADR-023 D4a: a couple-answer write requires the writer to carry a consent
    // record. Seed both members consented so the answer tests exercise the
    // reveal/shape invariants, not the consent gate (the D4a-negative test below
    // overwrites Alice with a consentless profile to isolate the predicate).
    await seedConsentedProfile(ALICE);
    await seedConsentedProfile(BOB);
  }

  /** Seeds an already-committed answer (owner context, real stamp). */
  async function seedAnswer(uid: string, text = 'Seeded.'): Promise<void> {
    await seed(answerPath(uid), {
      questionId: 'solo_tr_001',
      text,
      answeredAt: Timestamp.now(),
    });
  }

  it('a member creates their own answer with the frozen write shape', async () => {
    await seedCoupleDay();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, answerPath(ALICE)), answerWrite()));
  });

  // ADR-023 D4a: the consent predicate on the couple-answer write, isolated.
  it('a consented member writes their answer (D4a positive)', async () => {
    await seedCoupleDay(); // seeds ALICE + BOB consented
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(setDoc(doc(alice, answerPath(ALICE)), answerWrite()));
  });

  it('a member with a profile but NO consent is denied (D4a negative)', async () => {
    await seedCoupleDay();
    // Overwrite ALICE's profile with a consentless one; couple + day stay intact,
    // so only the consent predicate should now deny the otherwise-valid write.
    await seed(`users/${ALICE}`, { ...profileData, createdAt: Timestamp.now() });
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, answerPath(ALICE)), answerWrite()));
  });

  it('client-clock answeredAt is rejected (server stamp only)', async () => {
    await seedCoupleDay();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, answerPath(ALICE)), {
        ...answerWrite(),
        answeredAt: Timestamp.fromMillis(42),
      }),
    );
  });

  it('junk fields are rejected (hasOnly surface)', async () => {
    await seedCoupleDay();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, answerPath(ALICE)), {
        ...answerWrite(),
        mood: 'great',
      }),
    );
  });

  it('empty, oversized, and non-string text are rejected', async () => {
    await seedCoupleDay();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, answerPath(ALICE)), { ...answerWrite(), text: '' }),
    );
    await assertFails(
      setDoc(doc(alice, answerPath(ALICE)), {
        ...answerWrite(),
        text: 'x'.repeat(2001),
      }),
    );
    await assertFails(
      setDoc(doc(alice, answerPath(ALICE)), { ...answerWrite(), text: 42 }),
    );
  });

  it('the answer questionId must match the assigned day questionId', async () => {
    await seedCoupleDay();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, answerPath(ALICE)), {
        ...answerWrite(),
        questionId: 'solo_tr_007',
      }),
    );
  });

  it('answers to an unassigned day are rejected (day doc must exist)', async () => {
    // No day doc seeded: the questionId pin get()s the day doc, which fails
    // closed — no pre-answering future/garbage dayKeys.
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(
        doc(alice, `couples/couple-1/days/20991231/answers/${ALICE}`),
        answerWrite(),
      ),
    );
  });

  it('a member may not write the PARTNER answer doc', async () => {
    await seedCoupleDay();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, answerPath(BOB)), answerWrite()));
  });

  it('a non-member may not write an answer doc under a foreign couple', async () => {
    // isSelf(authorUid) alone would pass for Charlie writing answers/charlie;
    // the write-membership clause is the guard that stops it.
    await seedCoupleDay();
    const charlie = env.authenticatedContext(CHARLIE).firestore();
    await assertFails(setDoc(doc(charlie, answerPath(CHARLIE)), answerWrite()));
  });

  it('THE M3 invariant: the partner answer is unreadable before own answer exists', async () => {
    await seedCoupleDay();
    await seedAnswer(ALICE);
    // Bob has NOT answered: Alice's answer must be unreadable to him.
    await assertFails(
      getDoc(doc(env.authenticatedContext(BOB).firestore(), answerPath(ALICE))),
    );
  });

  it('own answer is readable while the partner slot stays locked', async () => {
    await seedCoupleDay();
    await seedAnswer(ALICE);
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), answerPath(ALICE))),
    );
  });

  it('both answers become mutually readable once both exist (reveal)', async () => {
    await seedCoupleDay();
    await seedAnswer(ALICE);
    await seedAnswer(BOB);
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(BOB).firestore(), answerPath(ALICE))),
    );
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), answerPath(BOB))),
    );
  });

  it('non-members and anonymous never read answers, even post-reveal', async () => {
    await seedCoupleDay();
    await seedAnswer(ALICE);
    await seedAnswer(BOB);
    await assertFails(
      getDoc(
        doc(env.authenticatedContext(CHARLIE).firestore(), answerPath(ALICE)),
      ),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), answerPath(ALICE))),
    );
  });

  it('answers under a missing parent couple are unreadable (fails closed)', async () => {
    await seed(DAY_PATH, {
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
    });
    await seedAnswer(ALICE);
    await assertFails(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), answerPath(ALICE))),
    );
  });

  it('listing the answers collection is denied pre-answer, allowed post-reveal', async () => {
    // The read rule's exists() disjunct is document-independent, so a
    // whole-collection list flips with the requester's own answer: pin both
    // sides so a rules refactor can't silently change list semantics.
    await seedCoupleDay();
    await seedAnswer(ALICE);
    await assertFails(
      getDocs(
        collection(
          env.authenticatedContext(BOB).firestore(),
          `${DAY_PATH}/answers`,
        ),
      ),
    );
    await seedAnswer(BOB);
    await assertSucceeds(
      getDocs(
        collection(
          env.authenticatedContext(BOB).firestore(),
          `${DAY_PATH}/answers`,
        ),
      ),
    );
  });

  it('own answer stays editable while the partner has not answered (typo window)', async () => {
    await seedCoupleDay();
    await seedAnswer(ALICE);
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      setDoc(doc(alice, answerPath(ALICE)), {
        ...answerWrite(),
        text: 'Düzeltilmiş cevap.',
      }),
    );
  });

  it('answers freeze once both exist — no post-reveal rewrites', async () => {
    // Editing after reading the partner would defeat the commit-before-see
    // premise; revealed = frozen (and answeredAt stays stable for M3.4).
    await seedCoupleDay();
    await seedAnswer(ALICE);
    await seedAnswer(BOB);
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(alice, answerPath(ALICE)), {
        ...answerWrite(),
        text: 'Rewritten after peeking.',
      }),
    );
  });

  it('clients never delete answers (reveal gate is one-way)', async () => {
    await seedCoupleDay();
    await seedAnswer(ALICE);
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(deleteDoc(doc(alice, answerPath(ALICE))));
  });
});

describe('subscriptions/{coupleId}', () => {
  const SUB_PATH = 'subscriptions/couple-1';

  // The entitlement mirror the revenueCatWebhook admin SDK writes (ADR-013
  // Decision 5): couple-level summary fields + per-uid lanes + a server stamp.
  const subscriptionData = () => ({
    entitled: true,
    productId: 'premium_annual',
    periodType: 'NORMAL',
    expiresAtMs: 1_799_999_999_000,
    willRenew: true,
    store: 'APP_STORE',
    environment: 'PRODUCTION',
    lanes: {
      [ALICE]: {
        entitled: true,
        productId: 'premium_annual',
        periodType: 'NORMAL',
        expiresAtMs: 1_799_999_999_000,
        willRenew: true,
        store: 'APP_STORE',
        environment: 'PRODUCTION',
        entitlementIds: ['premium'],
        lastEventId: 'evt-uuid-1',
        lastEventTimestampMs: 1_750_000_000_000,
        updatedAtMs: 1_750_000_000_000,
      },
    },
    updatedAt: Timestamp.now(),
  });

  async function seedSubscription(): Promise<void> {
    await seedCouple();
    await seed(SUB_PATH, subscriptionData());
  }

  it('members read the mirror; non-members and anonymous cannot', async () => {
    await seedSubscription();
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), SUB_PATH)),
    );
    await assertSucceeds(
      getDoc(doc(env.authenticatedContext(BOB).firestore(), SUB_PATH)),
    );
    await assertFails(
      getDoc(doc(env.authenticatedContext(CHARLIE).firestore(), SUB_PATH)),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), SUB_PATH)),
    );
  });

  it('a mirror doc under a missing parent couple is unreadable (fails closed)', async () => {
    // Orphaned mirror: parent couple never seeded. The membership get() finds
    // no couple, so the read must deny — corrupt state stays dark, matching
    // the M3.2 days/answers fail-closed discipline.
    await seed(SUB_PATH, subscriptionData());
    await assertFails(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), SUB_PATH)),
    );
  });

  it('no client writes at all — not even members (webhook admin SDK is sole writer)', async () => {
    // The revenueCatWebhook Function owns every write; create/update/delete are
    // all denied for a member (ADR-013 Decision 5, delete = M6 cascade).
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, SUB_PATH), subscriptionData()));

    await seed(SUB_PATH, subscriptionData());
    await assertFails(updateDoc(doc(alice, SUB_PATH), { entitled: false }));
    await assertFails(deleteDoc(doc(alice, SUB_PATH)));
  });
});

describe('coachUsage/{coupleId}', () => {
  // M5.1 (ADR-016 Decision 7): the coachProxy admin SDK is the sole writer. The
  // parent doc is the couple-shared MONTHLY bucket (member-read); the per-user
  // DAILY lane is split into a subcollection so a partner can NEVER read the
  // other's coach-usage frequency (the domestic-violence-aware split).
  const USAGE_PATH = 'coachUsage/couple-1';
  const DAILY_ALICE = 'coachUsage/couple-1/daily/alice-uid';
  const DAILY_BOB = 'coachUsage/couple-1/daily/bob-uid';

  const parentData = () => ({ monthly: { monthKey: '202607', count: 5 }, updatedAt: Timestamp.now() });
  const dailyData = () => ({ dayKey: '20260712', count: 3, updatedAt: Timestamp.now() });

  async function seedUsage(): Promise<void> {
    await seedCouple();
    await seed(USAGE_PATH, parentData());
    await seed(DAILY_ALICE, dailyData());
    await seed(DAILY_BOB, dailyData());
  }

  // --- parent doc (couple-shared monthly bucket) ---
  it('members read the parent monthly bucket; non-members and anonymous cannot', async () => {
    await seedUsage();
    await assertSucceeds(getDoc(doc(env.authenticatedContext(ALICE).firestore(), USAGE_PATH)));
    await assertSucceeds(getDoc(doc(env.authenticatedContext(BOB).firestore(), USAGE_PATH)));
    await assertFails(getDoc(doc(env.authenticatedContext(CHARLIE).firestore(), USAGE_PATH)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), USAGE_PATH)));
  });

  it('a parent doc under a missing couple is unreadable (fails closed)', async () => {
    // Orphaned counter: parent couple never seeded → the membership get() finds
    // nothing → deny, matching the subscriptions/days fail-closed discipline.
    await seed(USAGE_PATH, parentData());
    await assertFails(getDoc(doc(env.authenticatedContext(ALICE).firestore(), USAGE_PATH)));
  });

  it('no client writes to the parent — not even members (coachProxy admin SDK is sole writer)', async () => {
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, USAGE_PATH), parentData()));

    await seed(USAGE_PATH, parentData());
    await assertFails(updateDoc(doc(alice, USAGE_PATH), { monthly: { monthKey: '202607', count: 0 } }));
    await assertFails(deleteDoc(doc(alice, USAGE_PATH)));
  });

  // --- daily lane (per-user, self-read only) ---
  it('a member reads their OWN daily lane; the partner cannot (the domestic-violence pin)', async () => {
    await seedUsage();
    await assertSucceeds(getDoc(doc(env.authenticatedContext(ALICE).firestore(), DAILY_ALICE)));
    // BOB is a member of the couple, yet must NOT be able to read ALICE's lane.
    await assertFails(getDoc(doc(env.authenticatedContext(BOB).firestore(), DAILY_ALICE)));
    await assertFails(getDoc(doc(env.authenticatedContext(CHARLIE).firestore(), DAILY_ALICE)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), DAILY_ALICE)));
    // Symmetry: BOB reads his own lane fine.
    await assertSucceeds(getDoc(doc(env.authenticatedContext(BOB).firestore(), DAILY_BOB)));
  });

  it('no client writes to a daily lane — not even the owner', async () => {
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, DAILY_ALICE), dailyData()));

    await seed(DAILY_ALICE, dailyData());
    await assertFails(updateDoc(doc(alice, DAILY_ALICE), { count: 0 }));
    await assertFails(deleteDoc(doc(alice, DAILY_ALICE)));
  });
});

describe('invites/{code}', () => {
  const inviteData = () => ({
    creatorUid: ALICE,
    status: 'pending',
    expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    createdAt: Timestamp.now(),
  });

  it('no client can read an invite — not even its creator', async () => {
    await seed('invites/TESTCODE', inviteData());
    await assertFails(
      getDoc(doc(env.authenticatedContext(ALICE).firestore(), 'invites/TESTCODE')),
    );
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), 'invites/TESTCODE')),
    );
  });

  it('no client can create, update, or delete invites', async () => {
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertFails(setDoc(doc(alice, 'invites/NEWCODE23'), inviteData()));

    await seed('invites/TESTCODE', inviteData());
    await assertFails(
      updateDoc(doc(alice, 'invites/TESTCODE'), { status: 'accepted' }),
    );
    await assertFails(deleteDoc(doc(alice, 'invites/TESTCODE')));
  });
});

// ---------------------------------------------------------------------------
// Prove the net: weaken one protecting clause at a time in a COPY of the rules
// and show the previously-denied op now succeeds. Each mutant loads under its
// own projectId (rules are stored per project on the emulator, so reusing the
// main env's id would clobber its rules).
// ---------------------------------------------------------------------------

interface Mutation {
  name: string;
  /** Must appear verbatim in firestore.rules — keeps anchors from rotting. */
  anchor: string;
  replacement: string;
  /** Op denied under real rules that must SUCCEED under the mutant. */
  demonstrate: (mutant: RulesTestEnvironment) => Promise<unknown>;
}

// Shared seeding for the M3.3 answers mutants: couple-1 + its 20260710 day
// doc (rollover shape), optionally pre-existing answers, all owner-context.
const MUTANT_DAY_PATH = 'couples/couple-1/days/20260710';

async function seedMutantCoupleDay(mutant: RulesTestEnvironment): Promise<void> {
  await mutant.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'couples/couple-1'), {
      memberUids: [ALICE, BOB],
      timezone: 'Europe/Istanbul',
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(context.firestore(), MUTANT_DAY_PATH), {
      questionId: 'solo_tr_001',
      packId: 'solo_tr',
      packVersion: 1,
      assignedAt: Timestamp.now(),
    });
    // ADR-023 D4a: answer writes require the writer's consent record. Seed both
    // members consented so a write-mutant demonstration isolates the guard under
    // test rather than tripping the (separate) consent predicate.
    const consent = { version: 1, acceptedAt: Timestamp.now(), ageAttested: true };
    await setDoc(doc(context.firestore(), `users/${ALICE}`), {
      ...profileData,
      consent,
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(context.firestore(), `users/${BOB}`), {
      ...profileData,
      consent,
      createdAt: Timestamp.now(),
    });
  });
}

async function seedMutantAnswer(
  mutant: RulesTestEnvironment,
  uid: string,
): Promise<void> {
  await mutant.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `${MUTANT_DAY_PATH}/answers/${uid}`), {
      questionId: 'solo_tr_001',
      text: 'Seeded.',
      answeredAt: Timestamp.now(),
    });
  });
}

/** The repository's exact answer write shape, for mutant demonstrations. */
const mutantAnswerWrite = () => ({
  questionId: 'solo_tr_001',
  text: 'Bugün seninle gülümsedim.',
  answeredAt: serverTimestamp(),
});

const MUTATIONS: Mutation[] = [
  {
    name: 'dropping the createdAt-at-create guard readmits unstamped creates',
    anchor: '&& request.resource.data.createdAt == request.time',
    replacement: '',
    demonstrate: (mutant) =>
      setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        profileData,
      ),
  },
  {
    name: 'dropping the createdAt-frozen guard readmits createdAt rewrites',
    anchor: '&& request.resource.data.createdAt == resource.data.createdAt',
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
      });
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        { createdAt: Timestamp.fromMillis(42) },
      );
    },
  },
  {
    name: 'dropping the coupleId-at-create guard readmits client-set coupleId',
    anchor: "&& !('coupleId' in request.resource.data)",
    replacement: '',
    demonstrate: (mutant) =>
      setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        {
          ...profileData,
          createdAt: serverTimestamp(),
          coupleId: 'couple-x',
        },
      ),
  },
  {
    name: 'dropping the coupleId-frozen guard readmits coupleId rewrites',
    anchor:
      "&& request.resource.data.get('coupleId', null) == resource.data.get('coupleId', null)",
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          coupleId: 'couple-1',
          createdAt: Timestamp.now(),
        });
      });
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        { coupleId: 'couple-2' },
      );
    },
  },
  {
    // First occurrence of the membership check is the couples READ rule.
    name: 'dropping the couples membership check readmits non-member reads',
    anchor: '&& request.auth.uid in resource.data.memberUids;',
    replacement: ';',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
        });
      });
      return getDoc(
        doc(mutant.authenticatedContext(CHARLIE).firestore(), 'couples/couple-1'),
      );
    },
  },
  {
    // No trailing ';' in the anchor: since M3.3 the update rule continues
    // with the timezone/createdAt freeze clauses after this one.
    name: 'dropping the memberUids freeze readmits membership rewrites',
    anchor: '&& request.resource.data.memberUids == resource.data.memberUids',
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          // Real couple shape: the M3.3 timezone/createdAt freeze clauses
          // compare these fields, and an absent one fails closed.
          createdAt: Timestamp.now(),
        });
      });
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), 'couples/couple-1'),
        { memberUids: [ALICE, CHARLIE] },
      );
    },
  },
  {
    // The invites match block precedes the catch-all, so the first
    // 'allow read, write: if false;' belongs to invites. Allow-any there must
    // win over the catch-all deny (rules allows are OR'd across matches).
    name: 'opening the invites block readmits client invite writes',
    anchor: 'allow read, write: if false;',
    replacement: 'allow read, write: if request.auth != null;',
    demonstrate: (mutant) =>
      setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), 'invites/NEWCODE23'),
        {
          creatorUid: ALICE,
          status: 'pending',
          expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
        },
      ),
  },
  {
    // M2.4 soloAnswers. Multi-line anchor: the bare 'allow read: if
    // isSelf(uid);' also appears on the users doc itself, so the anchor
    // carries the subcollection match line to stay unique.
    name: 'weakening the soloAnswers read guard readmits cross-user reads',
    anchor:
      'match /soloAnswers/{dayKey} {\n        allow read: if isSelf(uid);',
    replacement:
      'match /soloAnswers/{dayKey} {\n        allow read: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          doc(context.firestore(), `users/${ALICE}/soloAnswers/20260710`),
          {
            questionId: 'solo_tr_003',
            text: 'Birlikte sakin bir sabah.',
            answeredAt: Timestamp.now(),
          },
        );
      });
      return getDoc(
        doc(
          mutant.authenticatedContext(CHARLIE).firestore(),
          `users/${ALICE}/soloAnswers/20260710`,
        ),
      );
    },
  },
  {
    name: 'weakening the soloAnswers write guard readmits cross-user writes',
    anchor: 'allow create, update: if isSelf(uid)\n          &&',
    replacement: 'allow create, update: if request.auth != null\n          &&',
    demonstrate: async (mutant) => {
      // ADR-019: soloAnswer writes require the owner's profile to exist, so the
      // isolated clause under test is only reachable when users/{owner} is present.
      // ADR-023 D4a: the consent predicate checks the WRITER (request.auth.uid =
      // Charlie), so seed Charlie consented too — otherwise the consent gate, not
      // the isSelf clause under test, would deny.
      await mutant.withSecurityRulesDisabled(async (context) => {
        const consent = { version: 1, acceptedAt: Timestamp.now(), ageAttested: true };
        await setDoc(doc(context.firestore(), `users/${ALICE}`), { ...profileData, consent, createdAt: Timestamp.now() });
        await setDoc(doc(context.firestore(), `users/${CHARLIE}`), { ...profileData, consent, createdAt: Timestamp.now() });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(CHARLIE).firestore(),
          `users/${ALICE}/soloAnswers/20260710`,
        ),
        {
          questionId: 'solo_tr_003',
          text: 'Forged by Charlie.',
          answeredAt: serverTimestamp(),
        },
      );
    },
  },
  {
    name: 'dropping the answeredAt server-stamp guard readmits client-clock stamps',
    anchor: '&& request.resource.data.answeredAt == request.time;',
    replacement: ';',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), { ...profileData, consent: { version: 1, acceptedAt: Timestamp.now(), ageAttested: true }, createdAt: Timestamp.now() });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `users/${ALICE}/soloAnswers/20260710`,
        ),
        {
          questionId: 'solo_tr_003',
          text: 'Backdated.',
          answeredAt: Timestamp.fromMillis(42),
        },
      );
    },
  },
  {
    name: 'dropping the soloAnswers hasOnly guard readmits junk fields',
    anchor:
      "&& request.resource.data.keys().hasOnly(['questionId', 'text', 'answeredAt'])",
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), { ...profileData, consent: { version: 1, acceptedAt: Timestamp.now(), ageAttested: true }, createdAt: Timestamp.now() });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `users/${ALICE}/soloAnswers/20260710`,
        ),
        {
          questionId: 'solo_tr_003',
          text: 'Birlikte sakin bir sabah.',
          answeredAt: serverTimestamp(),
          mood: 'great',
        },
      );
    },
  },
  {
    // M3.2 days: weakening membership on the day-doc read must readmit
    // non-member reads. Distinct anchor from the couples-read mutant above
    // (get() on the parent vs resource.data on the doc itself).
    name: 'dropping the days membership guard readmits non-member day reads',
    anchor:
      '&& request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.memberUids;',
    replacement: ';',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
        await setDoc(doc(context.firestore(), 'couples/couple-1/days/20260710'), {
          questionId: 'solo_tr_001',
          packId: 'solo_tr',
          packVersion: 1,
          assignedAt: Timestamp.now(),
        });
      });
      return getDoc(
        doc(
          mutant.authenticatedContext(CHARLIE).firestore(),
          'couples/couple-1/days/20260710',
        ),
      );
    },
  },
  {
    // M3.2 days: writes are denied by the explicit `allow write: if false`
    // (plus the catch-all). Swapping it for an authed-allow must readmit a
    // client day write — proving the deny clause is the net, not an accident.
    name: 'allowing authed day writes readmits client-written day docs',
    anchor: 'allow write: if false; // days: function-only (admin SDK)',
    replacement: 'allow write: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          'couples/couple-1/days/20260710',
        ),
        {
          questionId: 'client-forged',
          packId: 'solo_tr',
          packVersion: 1,
          assignedAt: Timestamp.now(),
        },
      );
    },
  },
  {
    // M3.3 THE reveal invariant: dropping the exists()-gate disjunct leaves
    // the read member-only, so a member reads the partner PRE-answer.
    name: 'dropping the reveal exists()-gate readmits pre-answer partner reads',
    anchor:
      '&& (request.auth.uid == authorUid || hasAnswered(request.auth.uid));',
    replacement: ';',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      await seedMutantAnswer(mutant, ALICE);
      // Bob has NOT answered.
      return getDoc(
        doc(
          mutant.authenticatedContext(BOB).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
      );
    },
  },
  {
    // Multi-line anchor: 'request.auth.uid in memberUids()' appears in the
    // answers read, create, AND update rules — the read context pins it.
    name: 'dropping the answers read-membership guard readmits non-member reads',
    anchor:
      'allow read: if request.auth != null\n            && request.auth.uid in memberUids()',
    replacement: 'allow read: if request.auth != null',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      await seedMutantAnswer(mutant, ALICE);
      // Charlie owns a (seeded) answer doc under the foreign couple's day, so
      // the exists()-gate passes; only membership stops him under real rules.
      await seedMutantAnswer(mutant, CHARLIE);
      return getDoc(
        doc(
          mutant.authenticatedContext(CHARLIE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
      );
    },
  },
  {
    // isSelf(charlie-uid) passes for Charlie writing answers/charlie-uid —
    // the write-membership clause is what stops the foreign-couple write.
    name: 'dropping the answers write-membership guard readmits non-member answer docs',
    anchor:
      'allow create: if isSelf(authorUid)\n            && request.auth.uid in memberUids()',
    replacement: 'allow create: if isSelf(authorUid)',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      // ADR-023 D4a: seed the non-member writer's consent so the ONLY thing the
      // real rules use to deny him is the membership clause under test.
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${CHARLIE}`), {
          ...profileData,
          consent: { version: 1, acceptedAt: Timestamp.now(), ageAttested: true },
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(CHARLIE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${CHARLIE}`,
        ),
        mutantAnswerWrite(),
      );
    },
  },
  {
    name: 'weakening the answers isSelf guard readmits writing the partner answer',
    anchor: 'allow create: if isSelf(authorUid)',
    replacement: 'allow create: if request.auth != null',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      // Alice (a member, so write-membership passes) forges BOB's answer doc.
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${BOB}`,
        ),
        mutantAnswerWrite(),
      );
    },
  },
  {
    // 'return' pins the answers surface function; the solo clause is '&& ...'.
    name: 'dropping the answers hasOnly guard readmits junk fields',
    anchor:
      "return request.resource.data.keys().hasOnly(['questionId', 'text', 'answeredAt'])",
    replacement: 'return true',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
        { ...mutantAnswerWrite(), mood: 'great' },
      );
    },
  },
  {
    // 14-space indent pins the answers block; the solo clause sits at 10.
    name: 'dropping the answers server-stamp guard readmits client-clock stamps',
    anchor:
      '\n              && request.resource.data.answeredAt == request.time;',
    replacement: ';',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
        { ...mutantAnswerWrite(), answeredAt: Timestamp.fromMillis(42) },
      );
    },
  },
  {
    // The questionId pin carries two invariants: the answer matches the
    // assigned question AND (via the get()) the day doc exists at all.
    // Demonstrate both denials disappearing.
    name: 'dropping the answers questionId-day pin readmits unassigned-day answers',
    anchor:
      '\n              && request.resource.data.questionId == get(/databases/$(database)/documents/couples/$(coupleId)/days/$(dayKey)).data.questionId',
    replacement: '',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      const alice = mutant.authenticatedContext(ALICE).firestore();
      // Half 1: an answer under a day the rollover never assigned.
      await setDoc(
        doc(alice, 'couples/couple-1/days/20991231/answers/' + ALICE),
        mutantAnswerWrite(),
      );
      // Half 2: an answer contradicting the assigned questionId.
      return setDoc(doc(alice, `${MUTANT_DAY_PATH}/answers/${ALICE}`), {
        ...mutantAnswerWrite(),
        questionId: 'solo_tr_007',
      });
    },
  },
  {
    // 14-space indent pins the answers block; the solo clause sits at 10.
    name: 'dropping the answers non-empty-text bound readmits empty answers',
    anchor: '\n              && request.resource.data.text.size() > 0',
    replacement: '',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
        { ...mutantAnswerWrite(), text: '' },
      );
    },
  },
  {
    name: 'dropping the both-answered freeze readmits post-reveal rewrites',
    anchor:
      '&& !(hasAnswered(memberUids()[0]) && hasAnswered(memberUids()[1]))',
    replacement: '',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      await seedMutantAnswer(mutant, ALICE);
      await seedMutantAnswer(mutant, BOB);
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
        { ...mutantAnswerWrite(), text: 'Rewritten after peeking.' },
      );
    },
  },
  {
    // The reveal gate is one-way only because delete is denied: an
    // answer→read→retract cycle would defeat commit-before-see.
    name: 'allowing answer deletes readmits answer retraction post-reveal',
    anchor:
      'allow delete: if false; // answers: reveal gate is one-way (M6 cascade deletes)',
    replacement: 'allow delete: if isSelf(authorUid);',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      await seedMutantAnswer(mutant, ALICE);
      await seedMutantAnswer(mutant, BOB);
      return deleteDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
      );
    },
  },
  {
    // M3.3 couples hardening: the stored timezone became dayKey-load-bearing
    // for the app, so it is frozen like memberUids.
    name: 'dropping the couples timezone freeze readmits timezone rewrites',
    anchor: '\n        && request.resource.data.timezone == resource.data.timezone',
    replacement: '',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), 'couples/couple-1'),
        { timezone: 'not-a-zone' },
      );
    },
  },
  {
    // Trailing ';' pins the couples clause: the users createdAt-freeze clause
    // is byte-identical but mid-rule (no ';').
    name: 'dropping the couples createdAt freeze readmits createdAt rewrites',
    anchor: '&& request.resource.data.createdAt == resource.data.createdAt;',
    replacement: ';',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), 'couples/couple-1'),
        { createdAt: Timestamp.fromMillis(42) },
      );
    },
  },
  {
    // M3.4 streak freeze (ADR-012): streak is admin-trigger-owned. Dropping the
    // symmetric-absence freeze readmits a client introducing/forging it — the
    // seeded couple has no streak, so a member writing one must succeed only
    // under the mutant. Newline+8-space anchor pins the couples clause (the
    // byte-different 'coupleId' get() freeze lives in the users block).
    name: 'dropping the couples streak freeze readmits client streak writes',
    anchor:
      "\n        && request.resource.data.get('streak', null) == resource.data.get('streak', null)",
    replacement: '',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), 'couples/couple-1'),
        { streak: { count: 999, lastMutualDate: '20260710', graceTokens: 0 } },
      );
    },
  },
  {
    // M4.1 subscriptions: the entitlement mirror is admin-SDK-only. Swapping the
    // write-deny for an authed-allow must readmit a client-written mirror doc —
    // proving the deny clause is the net, not an accident of the catch-all.
    name: 'allowing authed subscription writes readmits client-written mirror docs',
    anchor:
      'allow write: if false; // subscriptions: function-only (revenueCatWebhook, admin SDK)',
    replacement: 'allow write: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          'subscriptions/couple-1',
        ),
        {
          entitled: true,
          productId: 'client-forged',
          periodType: 'NORMAL',
          expiresAtMs: 1_799_999_999_000,
          willRenew: true,
          store: 'APP_STORE',
          environment: 'PRODUCTION',
          lanes: {},
          updatedAt: Timestamp.now(),
        },
      );
    },
  },
  {
    // M4.1 subscriptions: weakening the member-only read to bare auth must
    // readmit a non-member read. The multi-line anchor pins the subscriptions
    // block — its membership-get() line is byte-identical to the M3.2 days read
    // (which .replace would hit first), so the match line disambiguates.
    name: 'dropping the subscriptions membership guard readmits non-member mirror reads',
    anchor:
      'match /subscriptions/{coupleId} {\n      allow read: if request.auth != null\n        && request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.memberUids;',
    replacement:
      'match /subscriptions/{coupleId} {\n      allow read: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
        await setDoc(doc(context.firestore(), 'subscriptions/couple-1'), {
          entitled: true,
          productId: 'premium_annual',
          periodType: 'NORMAL',
          expiresAtMs: 1_799_999_999_000,
          willRenew: true,
          store: 'APP_STORE',
          environment: 'PRODUCTION',
          lanes: {},
          updatedAt: Timestamp.now(),
        });
      });
      return getDoc(
        doc(
          mutant.authenticatedContext(CHARLIE).firestore(),
          'subscriptions/couple-1',
        ),
      );
    },
  },
  {
    // M5.1 coachUsage PARENT: swapping the write-deny for an authed-allow must
    // readmit a client-written counter — proving the deny is the net, not the
    // catch-all. The comment disambiguates it from the daily-lane write-deny.
    name: 'allowing authed coachUsage parent writes readmits client-written counters',
    anchor: 'allow write: if false; // coachUsage: function-only (coachProxy, admin SDK)',
    replacement: 'allow write: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), 'coachUsage/couple-1'),
        { monthly: { monthKey: '202607', count: 0 }, updatedAt: Timestamp.now() },
      );
    },
  },
  {
    // M5.1 coachUsage PARENT read: weakening the member-only read to bare auth
    // must readmit a non-member read. The membership-get() line is byte-identical
    // to the subscriptions/days reads, so the match line disambiguates the anchor.
    name: 'dropping the coachUsage parent membership guard readmits non-member reads',
    anchor:
      'match /coachUsage/{coupleId} {\n      allow read: if request.auth != null\n        && request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.memberUids;',
    replacement: 'match /coachUsage/{coupleId} {\n      allow read: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
        await setDoc(doc(context.firestore(), 'coachUsage/couple-1'), {
          monthly: { monthKey: '202607', count: 5 },
          updatedAt: Timestamp.now(),
        });
      });
      return getDoc(
        doc(mutant.authenticatedContext(CHARLIE).firestore(), 'coachUsage/couple-1'),
      );
    },
  },
  {
    // M5.1 coachUsage DAILY lane: the write-deny is the net. The comment
    // disambiguates it from the parent write-deny above.
    name: 'allowing authed coachUsage daily writes readmits client-written lanes',
    anchor: 'allow write: if false; // coachUsage daily lanes: function-only',
    replacement: 'allow write: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), 'coachUsage/couple-1/daily/alice-uid'),
        { dayKey: '20260712', count: 0, updatedAt: Timestamp.now() },
      );
    },
  },
  {
    // M5.1 coachUsage DAILY lane read: the self-read guard is the domestic-violence
    // pin. Weakening it to bare auth must readmit the PARTNER (a member!) reading
    // the other's lane. The match line disambiguates the anchor.
    name: 'dropping the coachUsage daily self-read guard readmits partner reads',
    anchor:
      'match /daily/{uid} {\n        allow read: if request.auth != null && request.auth.uid == uid;',
    replacement: 'match /daily/{uid} {\n        allow read: if request.auth != null;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
        await setDoc(doc(context.firestore(), 'coachUsage/couple-1/daily/alice-uid'), {
          dayKey: '20260712',
          count: 3,
          updatedAt: Timestamp.now(),
        });
      });
      // BOB (the partner) reads ALICE's lane — denied under real rules, allowed
      // under the mutant.
      return getDoc(
        doc(mutant.authenticatedContext(BOB).firestore(), 'coachUsage/couple-1/daily/alice-uid'),
      );
    },
  },
  {
    // M6.2 (ADR-019 D6): the notificationPrivacy override is server-owned. Dropping
    // its symmetric-absence freeze readmits a client minting it — the seeded
    // profile has none, so a client write must succeed only under the mutant.
    name: 'dropping the users notificationPrivacy freeze readmits client override writes',
    anchor:
      "\n        && request.resource.data.get('notificationPrivacy', null) == resource.data.get('notificationPrivacy', null)",
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
      });
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        { notificationPrivacy: 'discreet' },
      );
    },
  },
  {
    // M6.2 (ADR-019 D3): the coupleEnded tombstone is server-owned. Dropping its
    // freeze readmits a client forging (or clearing) it. Trailing anchor pins the
    // last clause (the `;` stays after the notificationPrivacy line on removal).
    name: 'dropping the users coupleEnded freeze readmits client tombstone writes',
    anchor:
      "\n        && request.resource.data.get('coupleEnded', null) == resource.data.get('coupleEnded', null)",
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
      });
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        { coupleEnded: { at: Timestamp.now() } },
      );
    },
  },
  {
    // M6.2 (ADR-019 D3): coupleEnded is server-owned on the CREATE path too, not
    // just update. Dropping the create block readmits a client minting the
    // tombstone on a fresh self-create (the rules-create-mint-gap fix). The
    // '&& !(...)' anchor is unique to the create clause.
    name: 'dropping the users coupleEnded create block readmits client-minted tombstone at create',
    anchor: "\n        && !('coupleEnded' in request.resource.data)",
    replacement: '',
    demonstrate: (mutant) =>
      setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        {
          ...profileData,
          createdAt: serverTimestamp(),
          coupleEnded: { at: Timestamp.now() },
        },
      ),
  },
  {
    // M6.2 (ADR-019 D6): notificationPrivacy is server-owned on the CREATE path
    // too. Dropping the create block readmits a client minting the discreet
    // override on a fresh self-create (the rules-create-mint-gap fix).
    name: 'dropping the users notificationPrivacy create block readmits client-minted override at create',
    anchor: "\n        && !('notificationPrivacy' in request.resource.data)",
    replacement: '',
    demonstrate: (mutant) =>
      setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        {
          ...profileData,
          createdAt: serverTimestamp(),
          notificationPrivacy: 'discreet',
        },
      ),
  },
  {
    // M6.2 (ADR-019 D2): soloAnswer writes require the owner's profile to exist —
    // the deleted-user orphan-write guard. Dropping it readmits an orphan write by
    // a caller with no users doc (Bob has none here).
    name: 'dropping the soloAnswers profile-exists guard readmits orphan writes',
    anchor: '\n          && exists(/databases/$(database)/documents/users/$(uid))',
    replacement: '',
    demonstrate: async (mutant) => {
      // ADR-023 D4a interaction, recorded honestly: hasConsent() reads the writer's
      // users doc and so ALSO fails-closed when that doc is missing — it SUBSUMES
      // exists() for the profile-missing case. A truly profile-less Bob is now
      // denied by BOTH guards, so dropping exists() alone can no longer flip a
      // profile-less write to success. Per ADR-023 (answer-writers carry consent)
      // Bob is seeded consented; this mutant is retained to guard the exists()
      // ANCHOR from rotting and to exercise the exists()-removed path. The
      // profile-missing DENIAL invariant itself stays proven by the positive
      // 'orphan write is denied when the owner has no profile' test above.
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${BOB}`), {
          ...profileData,
          consent: { version: 1, acceptedAt: Timestamp.now(), ageAttested: true },
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(mutant.authenticatedContext(BOB).firestore(), `users/${BOB}/soloAnswers/20260710`),
        { questionId: 'solo_tr_003', text: 'orphan', answeredAt: serverTimestamp() },
      );
    },
  },
  {
    // M6.2 delete-deny coverage (the harness noted users lacked a delete mutant):
    // swapping the users delete-deny for a self-allow readmits self-deletion —
    // proving the deny is the net (the cascade deletes via the admin SDK only).
    name: 'allowing self users deletes readmits client profile deletion',
    anchor: 'documents (ADR-019).\n      allow delete: if false;',
    replacement: 'documents (ADR-019).\n      allow delete: if isSelf(uid);',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
      });
      return deleteDoc(doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`));
    },
  },
  {
    // M6.2 delete-deny coverage: soloAnswers self-delete mutant. The 8-space
    // delete + 6-space closing brace pins the soloAnswers block (the users delete
    // is 6-space, the answers delete carries a trailing comment).
    name: 'allowing self soloAnswers deletes readmits client answer deletion',
    anchor: '\n        allow delete: if false;\n      }',
    replacement: '\n        allow delete: if isSelf(uid);\n      }',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
        await setDoc(doc(context.firestore(), `users/${ALICE}/soloAnswers/20260710`), {
          questionId: 'solo_tr_003',
          text: 'Seeded.',
          answeredAt: Timestamp.now(),
        });
      });
      return deleteDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}/soloAnswers/20260710`),
      );
    },
  },
  {
    // M6.2 delete-deny coverage: couples member-delete mutant (the combined
    // `create, delete: if false;` split so delete becomes member-allow).
    name: 'allowing member couple deletes readmits client couple deletion',
    anchor: 'allow create, delete: if false;',
    replacement:
      'allow create: if false;\n      allow delete: if request.auth != null && request.auth.uid in resource.data.memberUids;',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
          createdAt: Timestamp.now(),
        });
      });
      return deleteDoc(doc(mutant.authenticatedContext(ALICE).firestore(), 'couples/couple-1'));
    },
  },
  {
    // S023 (ADR-023 D4): consent is server-owned on the CREATE path. Dropping the
    // create block readmits a client minting the consent record on a fresh
    // self-create (matching the coupleEnded/notificationPrivacy create-mint-gap).
    name: 'dropping the users consent create block readmits client-minted consent at create',
    anchor: "\n        && !('consent' in request.resource.data)",
    replacement: '',
    demonstrate: (mutant) =>
      setDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        {
          ...profileData,
          createdAt: serverTimestamp(),
          consent: { version: 1, acceptedAt: Timestamp.now(), ageAttested: true },
        },
      ),
  },
  {
    // S023 (ADR-023 D4): consent is frozen on UPDATE (symmetric absence). Dropping
    // the freeze readmits a client minting it — the seeded profile carries none, so
    // the client write succeeds only under the mutant.
    name: 'dropping the users consent freeze readmits client consent writes',
    anchor:
      "\n        && request.resource.data.get('consent', null) == resource.data.get('consent', null)",
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
      });
      return updateDoc(
        doc(mutant.authenticatedContext(ALICE).firestore(), `users/${ALICE}`),
        { consent: { version: 1, acceptedAt: Timestamp.now(), ageAttested: true } },
      );
    },
  },
  {
    // S023 (ADR-023 D4a): the soloAnswers consent predicate. Dropping it readmits a
    // consentless write by an owner whose profile EXISTS but carries no consent
    // (exists() passes; only the consent predicate denied under real rules).
    name: 'dropping the soloAnswers consent predicate readmits consentless answer writes',
    anchor:
      "\n          && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('consent', null) != null",
    replacement: '',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `users/${ALICE}/soloAnswers/20260710`,
        ),
        { questionId: 'solo_tr_003', text: 'no consent yet', answeredAt: serverTimestamp() },
      );
    },
  },
  {
    // S023 (ADR-023 D4a): the couple-answers consent predicate (the hasConsent()
    // helper, shared by create+update). Weakening it to `return true` readmits a
    // consentless member's answer write — the writer's profile carries no consent.
    name: 'weakening the answers consent predicate readmits consentless answer writes',
    anchor:
      "return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('consent', null) != null",
    replacement: 'return true',
    demonstrate: async (mutant) => {
      await seedMutantCoupleDay(mutant);
      // Overwrite ALICE with a consentless profile (couple + day stay intact).
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `users/${ALICE}`), {
          ...profileData,
          createdAt: Timestamp.now(),
        });
      });
      return setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `${MUTANT_DAY_PATH}/answers/${ALICE}`,
        ),
        mutantAnswerWrite(),
      );
    },
  },
];

describe('mutation tests — the suite goes red if a protecting rule is weakened', () => {
  MUTATIONS.forEach((mutation, index) => {
    it(mutation.name, async () => {
      // If the anchor rotted (rules refactor), fail loudly rather than
      // silently proving nothing.
      expect(rules).toContain(mutation.anchor);
      const mutant = await initializeTestEnvironment({
        projectId: `demo-hayati-mutant-${index}`,
        firestore: {
          rules: rules.replace(mutation.anchor, mutation.replacement),
        },
      });
      try {
        await assertSucceeds(Promise.resolve(mutation.demonstrate(mutant)));
      } finally {
        await mutant.cleanup();
      }
    });
  });
});
