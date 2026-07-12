import {
  DocumentSnapshot,
  FieldValue,
  Firestore,
  Timestamp,
} from 'firebase-admin/firestore';

import { normalizeInviteCode } from './invite-code';

/**
 * The couple's timezone drives the daily-rollover bucket (architecture.md §4).
 * The joiner's device supplies an IANA id; anything we don't recognise falls
 * back to this default rather than corrupting the schedule with a bad zone.
 * Istanbul is the founder-couple / TR soft-launch home zone (ADR-007).
 */
export const DEFAULT_COUPLE_TIMEZONE = 'Europe/Istanbul';

/**
 * IANA timezone allow-list, computed ONCE at module load. `Intl.supportedValuesOf`
 * is a Node 20 runtime built-in; the cast covers TS lib targets (ours is ES2023)
 * that don't yet declare it. Membership is the ONLY thing that keeps a
 * client-supplied zone; everything else resolves to DEFAULT_COUPLE_TIMEZONE.
 */
const SUPPORTED_TIMEZONES: ReadonlySet<string> = new Set(
  (
    Intl as unknown as {
      supportedValuesOf(key: 'timeZone'): string[];
    }
  ).supportedValuesOf('timeZone'),
);

/**
 * Validates a client-supplied IANA timezone against the runtime allow-list.
 * Absent or unrecognised → DEFAULT_COUPLE_TIMEZONE (never trust the wire value
 * to be a real zone — a garbage id would silently break the rollover schedule).
 */
export function resolveCoupleTimezone(timezone?: string): string {
  if (typeof timezone === 'string' && SUPPORTED_TIMEZONES.has(timezone)) {
    return timezone;
  }
  return DEFAULT_COUPLE_TIMEZONE;
}

/**
 * True when a users/{uid} doc already carries a `coupleId` — i.e. the account
 * is already half of a couple. `coupleId` is written ONLY by this join Function
 * (rules freeze it against clients, M2.3), so its presence is authoritative. A
 * MISSING doc reads false, so callers can pass a non-existent snapshot safely.
 */
export function hasCoupleId(snapshot: DocumentSnapshot): boolean {
  const coupleId = snapshot.get('coupleId');
  return typeof coupleId === 'string' && coupleId.length > 0;
}

/**
 * Why the invitee could not join. The handler maps 'unknown' → not-found and
 * every other reason → failed-precondition, carrying the reason verbatim in
 * `details.reason` (the FROZEN M2.3 wire contract the app matches on).
 */
export type JoinRejectionReason =
  | 'unknown'
  | 'expired'
  | 'consumed'
  | 'self-join'
  | 'already-paired'
  | 'profile-missing';

/**
 * Typed domain rejection (pattern: InviteCodeSpaceExhaustedError). The service
 * throws these from RE-READ transaction state — never from catching a commit
 * conflict — so the mapping to an HttpsError is a pure function of `reason`.
 */
export abstract class JoinInviteError extends Error {
  abstract readonly reason: JoinRejectionReason;
}

/** Invite doc absent, or a code that can't be a real code (normalize → null). */
export class UnknownInviteError extends JoinInviteError {
  readonly reason = 'unknown';
  constructor() {
    super('That invite code is not valid.');
    this.name = 'UnknownInviteError';
  }
}

/** status 'expired', or expiresAt missing / not a Timestamp / already past. */
export class ExpiredInviteError extends JoinInviteError {
  readonly reason = 'expired';
  constructor() {
    super('That invite has expired.');
    this.name = 'ExpiredInviteError';
  }
}

/** status 'joined' — a race loser or a reused code (the invite is spent). */
export class ConsumedInviteError extends JoinInviteError {
  readonly reason = 'consumed';
  constructor() {
    super('That invite has already been used.');
    this.name = 'ConsumedInviteError';
  }
}

/** The joiner is the creator: a couple needs two distinct people. */
export class SelfJoinError extends JoinInviteError {
  readonly reason = 'self-join';
  constructor() {
    super('You cannot join your own invite.');
    this.name = 'SelfJoinError';
  }
}

/** Joiner OR creator users/{uid} doc already carries a coupleId. */
export class AlreadyPairedError extends JoinInviteError {
  readonly reason = 'already-paired';
  constructor() {
    super('This account is already paired.');
    this.name = 'AlreadyPairedError';
  }
}

/** Joiner or creator has no users/{uid} profile document yet. */
export class ProfileMissingError extends JoinInviteError {
  readonly reason = 'profile-missing';
  constructor() {
    super('A profile is required before pairing.');
    this.name = 'ProfileMissingError';
  }
}

export interface JoinResult {
  /** The freshly created couples/{coupleId}. */
  coupleId: string;
}

/**
 * Consumes an invite `code` on behalf of `joinerUid`, creating the couple and
 * pairing both partners in ONE Firestore transaction (architecture.md §4, M2.3).
 *
 * Check order (deliberate — the FIRST failing condition wins, so callers get a
 * stable reason): existence → terminal-state (joined → consumed, then expired)
 * → self-join → profile-missing → already-paired. 'joined' is checked before
 * the expiry comparison because a spent invite is 'consumed' regardless of the
 * clock; self-join and profile-missing are checked before already-paired so a
 * caller learns the cheaper, more actionable reason first.
 *
 * Concurrency: all reads happen before any write, so two joiners racing the
 * same code serialize on the invite (and shared creator) doc. The admin SDK
 * retries the ABORTED loser, whose retry RE-READS the invite — now 'joined' —
 * and throws ConsumedInviteError. Typed rejections therefore always come from
 * re-read state, never from inspecting a commit conflict.
 */
export async function joinInvite(
  db: Firestore,
  joinerUid: string,
  rawCode: string,
  timezone?: string,
): Promise<JoinResult> {
  const code = normalizeInviteCode(rawCode);
  if (code === null) {
    // A code that can't be a real code short-circuits to the same 'unknown'
    // surface as an absent invite — no transaction, no enumeration oracle.
    throw new UnknownInviteError();
  }
  const coupleTimezone = resolveCoupleTimezone(timezone);

  return db.runTransaction(async (tx) => {
    const inviteRef = db.collection('invites').doc(code);
    const users = db.collection('users');

    // READ 1 — the invite. Its creatorUid tells us whose profile to read next,
    // so this must precede the user reads (still all-reads-before-writes).
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new UnknownInviteError();
    }
    const invite = inviteSnap.data()!;

    // Terminal-state: a 'joined' invite is spent (consumed) whatever the clock
    // says, so it is rejected before the expiry comparison below.
    if (invite.status === 'joined') {
      throw new ConsumedInviteError();
    }
    const expiresAt = invite.expiresAt;
    if (
      invite.status === 'expired' ||
      !(expiresAt instanceof Timestamp) ||
      expiresAt.toMillis() <= Date.now()
    ) {
      throw new ExpiredInviteError();
    }

    const creatorUid = invite.creatorUid as string;
    if (creatorUid === joinerUid) {
      throw new SelfJoinError();
    }

    // READS 2 & 3 — both profiles, in one round trip. creatorUid !== joinerUid
    // here (self-join already rejected), so these are two distinct docs.
    const joinerRef = users.doc(joinerUid);
    const creatorRef = users.doc(creatorUid);
    const [joinerSnap, creatorSnap] = await tx.getAll(joinerRef, creatorRef);
    if (!joinerSnap.exists || !creatorSnap.exists) {
      throw new ProfileMissingError();
    }
    if (hasCoupleId(joinerSnap) || hasCoupleId(creatorSnap)) {
      throw new AlreadyPairedError();
    }

    // WRITES — the couple id is minted here (inside the transaction) so a
    // retried, doomed attempt never leaves an orphan couple behind.
    const coupleRef = db.collection('couples').doc();
    tx.create(coupleRef, {
      // Creator first: documents who opened the invite (architecture.md §3).
      memberUids: [creatorUid, joinerUid],
      timezone: coupleTimezone,
      createdAt: FieldValue.serverTimestamp(),
    });
    // coupleEnded is the M6.2 partner-notification tombstone (ADR-019 D3): a
    // re-pairing member must not carry a stale one, so the join clears it from
    // BOTH docs atomically with the coupleId write. FieldValue.delete() is a
    // no-op when the field is absent (the common case).
    tx.update(joinerRef, { coupleId: coupleRef.id, coupleEnded: FieldValue.delete() });
    tx.update(creatorRef, { coupleId: coupleRef.id, coupleEnded: FieldValue.delete() });
    tx.update(inviteRef, {
      status: 'joined',
      coupleId: coupleRef.id,
      joinerUid,
      joinedAt: FieldValue.serverTimestamp(),
    });
    return { coupleId: coupleRef.id };
  });
}
