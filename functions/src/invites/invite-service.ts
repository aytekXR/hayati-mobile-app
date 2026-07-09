import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';

import { generateInviteCode } from './invite-code';
import { hasCoupleId } from './join-service';

/**
 * Invite lifetime. 48h covers "sent the WhatsApp message Friday night, partner
 * opens it Sunday" without leaving codes valid for weeks; expired invites are
 * lazily marked 'expired' on the creator's next issue (a periodic cleanup
 * Function is planned alongside the other cleanup work, architecture.md §2).
 */
export const INVITE_TTL_MS = 48 * 60 * 60 * 1000;

/**
 * Collision-probe budget per issue attempt. At 31^8 ≈ 8.5e11 codes even one
 * collision is vanishingly rare at our scale; hitting this limit means the
 * generator is broken, so we fail loudly rather than loop.
 */
export const MAX_CODE_ATTEMPTS = 5;

export interface IssuedInvite {
  code: string;
  expiresAtMillis: number;
  /** True when an existing still-active invite was returned instead of a new one. */
  reused: boolean;
}

export class InviteCodeSpaceExhaustedError extends Error {
  constructor() {
    super(`no free invite code after ${MAX_CODE_ATTEMPTS} attempts`);
    this.name = 'InviteCodeSpaceExhaustedError';
  }
}

/**
 * The creator is already half of a couple, so minting (or re-issuing) an invite
 * is meaningless — one account pairs once (M2.3). Mapped by create-invite.ts to
 * failed-precondition {reason: 'already-paired'}, matching the join Function's
 * own already-paired surface.
 */
export class CreatorAlreadyPairedError extends Error {
  constructor() {
    super('creator is already paired');
    this.name = 'CreatorAlreadyPairedError';
  }
}

/**
 * Issues a pairing code for `creatorUid` (architecture.md §3, invites/{code}).
 *
 * Re-issue policy (documented decision, Session 007): ONE active invite per
 * creator — while a pending, unexpired invite exists it is returned as-is
 * (idempotent: re-opening the share flow never invalidates the code the
 * partner already received). Stale pending invites are marked 'expired' and
 * replaced. Invites never accumulate.
 *
 * Concurrency: everything runs in one transaction. The pending-invite query
 * takes locks on the matched docs and `tx.create` fails if the code doc
 * appeared meanwhile, so two concurrent calls serialize — the loser retries
 * (admin SDK retries ABORTED commits) and returns the winner's code.
 */
export async function issueInvite(
  db: Firestore,
  creatorUid: string,
  generateCode: () => string = generateInviteCode,
): Promise<IssuedInvite> {
  return db.runTransaction(async (tx) => {
    const invites = db.collection('invites');
    const now = Timestamp.now();

    // M2.3 guard (read-before-writes): a creator who is already paired must not
    // mint OR re-use an invite, so this precedes the pending-invite lookup and
    // the reuse-return below. A MISSING users doc keeps the M2.1 behavior
    // (proceed) — issuing does not itself require a profile; only pairing does.
    const creatorSnap = await tx.get(db.collection('users').doc(creatorUid));
    if (hasCoupleId(creatorSnap)) {
      throw new CreatorAlreadyPairedError();
    }

    // Equality-only conjunction: served by Firestore's merged single-field
    // indexes — no composite index entry needed (the emulator would not catch
    // a missing one; this is why the shape stays equality-only).
    const pending = await tx.get(
      invites
        .where('creatorUid', '==', creatorUid)
        .where('status', '==', 'pending'),
    );

    const active = pending.docs.find(
      (doc) => (doc.get('expiresAt') as Timestamp).toMillis() > now.toMillis(),
    );
    if (active) {
      return {
        code: active.id,
        expiresAtMillis: (active.get('expiresAt') as Timestamp).toMillis(),
        reused: true,
      };
    }

    // Probe for a free code — transactions require all reads before writes,
    // so collision handling happens here, not by catching a failed write.
    let code: string | null = null;
    for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt += 1) {
      const candidate = generateCode();
      const existing = await tx.get(invites.doc(candidate));
      if (!existing.exists) {
        code = candidate;
        break;
      }
    }
    if (code === null) {
      throw new InviteCodeSpaceExhaustedError();
    }

    // Lazy expiry: stale pending invites flip to 'expired' (kept for audit;
    // deletion is a future cleanup Function's job).
    for (const stale of pending.docs) {
      tx.update(stale.ref, { status: 'expired' });
    }

    // Server-set expiry: computed from the transaction's clock, never from
    // anything client-supplied.
    const expiresAt = Timestamp.fromMillis(now.toMillis() + INVITE_TTL_MS);
    tx.create(invites.doc(code), {
      creatorUid,
      status: 'pending',
      expiresAt,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { code, expiresAtMillis: expiresAt.toMillis(), reused: false };
  });
}
