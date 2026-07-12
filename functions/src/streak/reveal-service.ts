// M3.4 reveal service — the transactional core the repo's first Firestore
// trigger (on-answer-created.ts) drives (ADR-012 Decision 1 & 3). ONE Firestore
// transaction reads the day doc, the couple doc, and BOTH answer docs, then
// latches the mutual-day reveal exactly once:
//
//   - both answers exist AND the day has no revealedAt  → stamp revealedAt AND
//     fold the mutual day into couples.streak (applyMutualDay). THE M3.3
//     deferral lands here. This is the latch: Firestore transactions are
//     serializable and the ABSENCE of the partner answer / of revealedAt is in
//     the read set, so a concurrent second-answer create forces a retry and
//     EXACTLY one committed transaction observes "both exist, unrevealed".
//   - both exist AND revealedAt already present          → no-op (duplicate
//     delivery, or the loser of the two-answers race). No writes, no sends.
//   - only the author's answer exists                    → no reveal; the
//     partner-answered nudge (Decision 3) is the invocation's only effect.
//
// Corrupt/absent state (missing couple, missing day, author not a member,
// unidentifiable partner, a malformed dayKey the streak engine would reject) is
// a LOUD, TYPED skip — NEVER a throw. At-least-once delivery must not retry-loop
// on poison state (ADR-012); an unexpected systemic error still propagates so
// the handler logs it.
//
// Push sends happen AFTER the transaction commits, never inside it, and only on
// the invocation that won the latch (reveal) or observed the one-answer state
// (nudge). Sends are best-effort: the transactional invariant above is what must
// never break, so token/recipient/quiet-hour skips and send failures are logged
// and counted, never thrown. All policy is the covered pure modules
// (payload-policy, local-hour, recipients); the SEND is the injected
// MessagingPort (FCM has no emulator).
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { isQuietLocalHour, localHour } from '../notifications/local-hour';
import type { MessagingPort } from '../notifications/messaging-port';
import { PushKind, composePush } from '../notifications/payload-policy';
import {
  contentLanguageOf,
  fcmTokensOf,
  notificationPrivacyOf,
  resolveDiscreet,
} from '../notifications/recipients';
import { StreakState, applyMutualDay, parseStreakChecked } from './streak';

/** The three path params the trigger extracts from the answer doc that fired it. */
export interface AnswerCreatedEvent {
  coupleId: string;
  dayKey: string;
  authorUid: string;
}

/** Every non-Firestore/messaging dependency injectable; production uses defaults. */
export interface RevealServiceDeps {
  /** Clock for quiet-hours resolution (injected at couple-local 23:00 in tests). */
  now?: () => Date;
  /**
   * Test-only seam: awaited on the reveal path AFTER the transaction's reads and
   * BEFORE its writes, `attempt` being the 0-based transaction try. Lets a test
   * force a deterministic interleave of two concurrent invocations (the
   * two-answers race) — gate it on attempt 0 only, or a retry deadlocks. Mirrors
   * the M3.2 rollover async-seam pattern. Undefined in production.
   */
  beforeWrite?: (attempt: number) => Promise<void>;
}

/** What the transaction decided; the reveal/one-answer paths carry a push recipient. */
export type RevealDecision = 'revealed' | 'already-revealed' | 'one-answer' | 'skipped';

/** Why a corrupt/absent-state invocation skipped (each is logged loudly). */
export type SkipReason =
  | 'couple-missing'
  | 'day-missing'
  | 'not-a-member'
  | 'malformed-members'
  | 'author-answer-missing'
  | 'invalid-daykey';

/** Terminal state of the best-effort push attempt (all but 'sent' are loud skips). */
export type PushStatus =
  | 'sent'
  | 'no-user-doc'
  | 'no-tokens'
  | 'suppressed-quiet-hours'
  | 'send-failed';

export interface PushOutcome {
  kind: PushKind;
  recipientUid: string;
  status: PushStatus;
  /** Tokens resolved on the recipient (0 for no-user-doc / no-tokens). */
  tokenCount: number;
  sentCount: number;
  failedCount: number;
}

/** Typed summary the handler logs and the tests assert on. */
export interface HandleAnswerCreatedOutcome {
  decision: RevealDecision;
  coupleId: string;
  dayKey: string;
  authorUid: string;
  /** Present only when decision === 'skipped'. */
  skipReason?: SkipReason;
  /** True iff this invocation wrote couples.streak (the latch winner). */
  streakApplied: boolean;
  /** True iff the STORED streak was malformed (parseStreakChecked flagged it). */
  streakCorrupt: boolean;
  /** The streak state written on the reveal path (for the structured log). */
  streak?: StreakState;
  /** The post-commit push attempt, or null when no push fires. */
  push: PushOutcome | null;
}

/** What the transaction hands back to the (post-commit) push phase. */
interface TxOutcome {
  decision: RevealDecision;
  skipReason?: SkipReason;
  /** Recipient of the reveal/nudge push: always the PARTNER of event.authorUid. */
  partnerUid?: string;
  /** Couple-local zone for the quiet-hours check (verbatim from the couple doc). */
  timezone?: string;
  streakApplied: boolean;
  streakCorrupt: boolean;
  streak?: StreakState;
}

/**
 * Reads memberUids off the couple doc and returns the partner of `authorUid`, or
 * a skip reason. memberUids is the M2.3 join Function's write (a 2-element uid
 * array); anything else here is corrupt state to surface, not to guess around.
 */
function resolvePartner(
  memberUids: unknown,
  authorUid: string,
): { partnerUid: string } | { skipReason: SkipReason } {
  if (!Array.isArray(memberUids) || !memberUids.every((u): u is string => typeof u === 'string')) {
    return { skipReason: 'malformed-members' };
  }
  if (!memberUids.includes(authorUid)) {
    return { skipReason: 'not-a-member' };
  }
  const partnerUid = memberUids.find((u) => u !== authorUid);
  if (partnerUid === undefined) {
    // memberUids is [authorUid] (or all-same): no distinct partner to reveal to.
    return { skipReason: 'malformed-members' };
  }
  return { partnerUid };
}

/**
 * Drives one answer-created invocation. Returns a typed outcome for every
 * decidable case (reveal, no-op, nudge, skip); only a truly unexpected systemic
 * failure (e.g. Firestore unavailable) escapes, for the handler to log.
 */
export async function handleAnswerCreated(
  db: Firestore,
  messaging: MessagingPort,
  event: AnswerCreatedEvent,
  deps: RevealServiceDeps = {},
): Promise<HandleAnswerCreatedOutcome> {
  const { coupleId, dayKey, authorUid } = event;
  const now = deps.now ?? (() => new Date());

  const coupleRef = db.collection('couples').doc(coupleId);
  const dayRef = coupleRef.collection('days').doc(dayKey);
  const answersCol = dayRef.collection('answers');

  let attempt = 0;
  const tx = await db.runTransaction<TxOutcome>(async (transaction) => {
    const currentAttempt = attempt;
    attempt += 1;

    // Read the couple FIRST — its memberUids name the partner answer doc path.
    const coupleSnap = await transaction.get(coupleRef);
    if (!coupleSnap.exists) {
      return { decision: 'skipped', skipReason: 'couple-missing', streakApplied: false, streakCorrupt: false };
    }
    const partner = resolvePartner(coupleSnap.get('memberUids'), authorUid);
    if ('skipReason' in partner) {
      return { decision: 'skipped', skipReason: partner.skipReason, streakApplied: false, streakCorrupt: false };
    }
    const { partnerUid } = partner;
    const timezone = coupleSnap.get('timezone');

    const daySnap = await transaction.get(dayRef);
    if (!daySnap.exists) {
      return { decision: 'skipped', skipReason: 'day-missing', streakApplied: false, streakCorrupt: false };
    }

    // The absence of EITHER answer doc joins the read set here — that is what
    // makes a concurrent second-answer create force this transaction to retry
    // rather than decide on a stale "one answer" view (ADR-012 D1 latch).
    const [authorSnap, partnerSnap] = await transaction.getAll(
      answersCol.doc(authorUid),
      answersCol.doc(partnerUid),
    );

    const partnerTz = typeof timezone === 'string' ? timezone : undefined;

    if (!authorSnap.exists) {
      // The doc whose CREATE fired us is gone (deletes are rules-denied, so this
      // is corrupt state): nothing to reveal or nudge about. Loud skip.
      return { decision: 'skipped', skipReason: 'author-answer-missing', streakApplied: false, streakCorrupt: false };
    }

    if (!partnerSnap.exists) {
      // Only the author has answered → no reveal; the partner-answered nudge is
      // this invocation's whole effect (a benign race may nudge a partner whose
      // own answer is milliseconds from committing — best-effort by design).
      return { decision: 'one-answer', partnerUid, timezone: partnerTz, streakApplied: false, streakCorrupt: false };
    }

    // Both answers exist. Either we win the latch (unrevealed) or observe it
    // already closed (duplicate delivery / race loser).
    if (daySnap.get('revealedAt') != null) {
      return { decision: 'already-revealed', partnerUid, streakApplied: false, streakCorrupt: false };
    }

    // Latch winner. Compute the streak fold BEFORE any write so a malformed
    // dayKey (a corrupt day-doc id the engine rejects) becomes a no-op skip, not
    // a throw that would abort-and-retry-loop under at-least-once delivery.
    const parsed = parseStreakChecked(coupleSnap.get('streak'));
    let nextStreak: StreakState;
    try {
      nextStreak = applyMutualDay(parsed.state, dayKey);
    } catch {
      return { decision: 'skipped', skipReason: 'invalid-daykey', streakApplied: false, streakCorrupt: parsed.corrupt };
    }

    // Test seam: force the read→write interleave of a concurrent invocation.
    await deps.beforeWrite?.(currentAttempt);

    // The day doc stays client-write-denied (admin write); the couple streak is
    // the pure engine's result, a full StreakState map replacing the field.
    transaction.update(dayRef, { revealedAt: FieldValue.serverTimestamp() });
    transaction.update(coupleRef, { streak: nextStreak });

    return {
      decision: 'revealed',
      partnerUid,
      timezone: partnerTz,
      streakApplied: true,
      streakCorrupt: parsed.corrupt,
      streak: nextStreak,
    };
  });

  if (tx.decision === 'skipped') {
    logger.warn('answer_reveal: skipped corrupt/absent state', {
      coupleId,
      dayKey,
      authorUid,
      reason: tx.skipReason,
    });
  }
  if (tx.streakCorrupt) {
    // parseStreakChecked contract: a PRESENT-but-malformed stored streak is a bug
    // or a manual poke on an admin-owned field — surfaced loudly, never trusted
    // (the engine ran from INITIAL_STREAK instead).
    logger.error('answer_reveal: stored streak was malformed, applied from INITIAL', {
      coupleId,
      dayKey,
    });
  }

  // Post-commit push phase (never inside the transaction). Exactly one recipient
  // — the partner of event.authorUid — on the reveal (first-answerer) and
  // one-answer (has-not-answered) paths; the other decisions send nothing.
  let push: PushOutcome | null = null;
  if (tx.decision === 'revealed' && tx.partnerUid !== undefined) {
    push = await deliverPush(db, messaging, tx.partnerUid, 'reveal', tx.timezone, now);
  } else if (tx.decision === 'one-answer' && tx.partnerUid !== undefined) {
    push = await deliverPush(db, messaging, tx.partnerUid, 'partnerAnswered', tx.timezone, now);
  }

  const outcome: HandleAnswerCreatedOutcome = {
    decision: tx.decision,
    coupleId,
    dayKey,
    authorUid,
    skipReason: tx.skipReason,
    streakApplied: tx.streakApplied,
    streakCorrupt: tx.streakCorrupt,
    streak: tx.streak,
    push,
  };
  logger.info('answer_reveal: complete', {
    coupleId,
    dayKey,
    authorUid,
    decision: outcome.decision,
    streakApplied: outcome.streakApplied,
    push: push === null ? 'none' : { kind: push.kind, status: push.status, sentCount: push.sentCount },
  });
  return outcome;
}

/**
 * Resolve one recipient (post-transaction) and best-effort send. Every branch
 * that stops short of sending is a TYPED, LOGGED skip counted in the outcome;
 * the send loop swallows per-token failures. Nothing here throws — a push that
 * cannot go out must never undo the committed reveal/streak.
 */
async function deliverPush(
  db: Firestore,
  messaging: MessagingPort,
  recipientUid: string,
  kind: PushKind,
  timezone: string | undefined,
  now: () => Date,
): Promise<PushOutcome> {
  const base = { kind, recipientUid, tokenCount: 0, sentCount: 0, failedCount: 0 } as const;
  try {
    const userSnap = await db.collection('users').doc(recipientUid).get();
    if (!userSnap.exists) {
      logger.warn('answer_reveal: push skipped, no user doc', { recipientUid, kind });
      return { ...base, status: 'no-user-doc' };
    }
    const userData = userSnap.data();
    const tokens = fcmTokensOf(userData);
    if (tokens.length === 0) {
      // Expected until on-device fcmTokens capture ships (ADR-012 operator item
      // 4): loud so token coverage is observable, never an error.
      logger.warn('answer_reveal: push skipped, no fcm tokens', { recipientUid, kind });
      return { ...base, status: 'no-tokens' };
    }

    // Quiet hours drop the push (no queue/scheduling infra this session); a
    // missing/invalid stored zone throws out of localHour and is caught below —
    // an undeliverable push is never worth surfacing corrupt-zone state as a
    // reveal failure.
    if (timezone === undefined) {
      logger.warn('answer_reveal: push skipped, couple timezone unresolved', { recipientUid, kind });
      return { ...base, tokenCount: tokens.length, status: 'send-failed' };
    }
    if (isQuietLocalHour(localHour(now(), timezone))) {
      logger.info('answer_reveal: push suppressed, couple-local quiet hours', { recipientUid, kind });
      return { ...base, tokenCount: tokens.length, status: 'suppressed-quiet-hours' };
    }

    const language = contentLanguageOf(userData);
    const payload = composePush({
      kind,
      language,
      discreet: resolveDiscreet(language, notificationPrivacyOf(userData)),
    });

    let sentCount = 0;
    let failedCount = 0;
    for (const token of tokens) {
      try {
        await messaging.send({ token, title: payload.title, body: payload.body });
        sentCount += 1;
      } catch (error) {
        failedCount += 1;
        logger.error('answer_reveal: push send failed', {
          recipientUid,
          kind,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    return {
      ...base,
      tokenCount: tokens.length,
      sentCount,
      failedCount,
      status: sentCount > 0 ? 'sent' : 'send-failed',
    };
  } catch (error) {
    // Any unexpected failure resolving the recipient (bad zone, read error): the
    // reveal already committed, so this is best-effort noise, not a throw.
    logger.error('answer_reveal: push delivery errored', {
      recipientUid,
      kind,
      error: error instanceof Error ? error.message : String(error),
    });
    return { ...base, status: 'send-failed' };
  }
}
