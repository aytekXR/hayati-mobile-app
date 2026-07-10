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
  deleteDoc,
  deleteField,
  doc,
  getDoc,
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

/** A real-shaped couple: exactly what the M2.3 join Function writes. */
async function seedCouple(): Promise<void> {
  await seed('couples/couple-1', {
    memberUids: [ALICE, BOB],
    timezone: 'Europe/Istanbul',
    createdAt: Timestamp.now(),
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

  it('members update non-membership fields', async () => {
    await seedCouple();
    const alice = env.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      updateDoc(doc(alice, 'couples/couple-1'), { timezone: 'Asia/Riyadh' }),
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
    name: 'dropping the memberUids freeze readmits membership rewrites',
    anchor: '&& request.resource.data.memberUids == resource.data.memberUids;',
    replacement: ';',
    demonstrate: async (mutant) => {
      await mutant.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'couples/couple-1'), {
          memberUids: [ALICE, BOB],
          timezone: 'Europe/Istanbul',
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
    demonstrate: (mutant) =>
      setDoc(
        doc(
          mutant.authenticatedContext(CHARLIE).firestore(),
          `users/${ALICE}/soloAnswers/20260710`,
        ),
        {
          questionId: 'solo_tr_003',
          text: 'Forged by Charlie.',
          answeredAt: serverTimestamp(),
        },
      ),
  },
  {
    name: 'dropping the answeredAt server-stamp guard readmits client-clock stamps',
    anchor: '&& request.resource.data.answeredAt == request.time;',
    replacement: ';',
    demonstrate: (mutant) =>
      setDoc(
        doc(
          mutant.authenticatedContext(ALICE).firestore(),
          `users/${ALICE}/soloAnswers/20260710`,
        ),
        {
          questionId: 'solo_tr_003',
          text: 'Backdated.',
          answeredAt: Timestamp.fromMillis(42),
        },
      ),
  },
  {
    name: 'dropping the soloAnswers hasOnly guard readmits junk fields',
    anchor:
      "&& request.resource.data.keys().hasOnly(['questionId', 'text', 'answeredAt'])",
    replacement: '',
    demonstrate: (mutant) =>
      setDoc(
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
      ),
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
