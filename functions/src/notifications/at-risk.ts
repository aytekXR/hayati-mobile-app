// streak-at-risk push pass — PIGGYBACKED on the hourly questionRollover sweep
// (ADR-012 Decision 3), never a second scheduled Function. The sweep already
// lists every couple ONCE and buckets them by stored timezone (rollover-service
// bucketCouplesByTimezone); this pass reuses that SAME snapshot — the hard
// constraint is exactly one couples-collection read per production sweep, so the
// handler threads its single CoupleBuckets into both the assignment pass and this
// one. On the sweep whose bucket-local hour is 20 (AT_RISK_LOCAL_HOUR), a couple
// with something to lose (streak.count > 0) whose day doc is still unrevealed gets
// a nudge to whichever member has not answered. Best-effort by design: no dedup
// state — the hourly cadence + the once-per-zone hour-20 gate make double-sends
// structurally absent, not guarded (ADR-012 D3).
import { Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { localDayKey } from '../rollover/day-key';
import type { CoupleBuckets } from '../rollover/rollover-service';
import { parseStreak } from '../streak/streak';
import { isQuietLocalHour, localHour } from './local-hour';
import type { MessagingPort } from './messaging-port';
import { composePush } from './payload-policy';
import { contentLanguageOf, fcmTokensOf, resolveDiscreet } from './recipients';

// The couple-LOCAL wall-clock hour the at-risk push fires on (ADR-012 D3): once
// per zone per day — only the sweep whose bucket-local hour reads 20 pushes. 20 is
// OUTSIDE the 22:00–08:00 quiet window by construction (deliverAtRiskPush still
// re-checks, defense in depth). Sub-hour-offset zones (Asia/Kathmandu +05:45) land
// on the hourly sweep whose local clock reads 20:xx, exactly as their midnight
// bucket does. DST transitions never occur at 20:xx in practice.
export const AT_RISK_LOCAL_HOUR = 20;

/** The at-risk sweep counters the handler logs and the tests assert on. */
export interface AtRiskSummary {
  /** Eligible couples (streak.count > 0 AND today's day doc exists unrevealed). */
  checked: number;
  /** At-risk pushes delivered (≥1 token accepted by the port). */
  sent: number;
  /** Recipients with no fcm token — a loud skip (expected pre-on-device capture). */
  skippedNoToken: number;
  /** Couples with streak > 0 but NO day doc for today (rollover failed earlier —
   *  nothing to answer, so NOT an at-risk state; counted separately). */
  skippedNoDay: number;
  /** Sends dropped by the defense-in-depth quiet-hours check (0 at hour 20 by
   *  construction; the counter exists so the guard is observable if it ever fires). */
  suppressedQuiet: number;
  /** Per-token send failures + per-couple processing errors, all swallowed. */
  failed: number;
}

/** Terminal state of one recipient's best-effort send; every field is a summary increment. */
interface AtRiskPushOutcome {
  status: 'sent' | 'no-tokens' | 'suppressed-quiet-hours' | 'send-failed';
  sent: number;
  skippedNoToken: number;
  suppressedQuiet: number;
  failed: number;
}

/**
 * Resolve one recipient and best-effort send the streak-at-risk push. Mirrors the
 * reveal trigger's deliverPush (reveal-service.ts) but for the sweep: every branch
 * short of a delivered send is a TYPED, LOGGED skip whose numeric fields the caller
 * folds straight into the summary (no per-status switch, so aggregation is
 * branch-free). NOTHING here throws — a push that cannot go out must never fail the
 * sweep. `at` is the sweep instant, used as the clock for the quiet-hours guard.
 */
export async function deliverAtRiskPush(
  db: Firestore,
  messaging: MessagingPort,
  recipientUid: string,
  streakCount: number,
  timezone: string,
  at: Date,
): Promise<AtRiskPushOutcome> {
  const base = { sent: 0, skippedNoToken: 0, suppressedQuiet: 0, failed: 0 } as const;
  try {
    const userSnap = await db.collection('users').doc(recipientUid).get();
    // A missing user doc and an empty/junk fcmTokens field collapse to the same
    // "nothing to send to" skip (ADR-012: fcmTokensOf → [] on absent/malformed).
    const userData = userSnap.exists ? userSnap.data() : undefined;
    const tokens = fcmTokensOf(userData);
    if (tokens.length === 0) {
      logger.warn('question_rollover: at-risk push skipped, no fcm tokens', { recipientUid });
      return { ...base, status: 'no-tokens', skippedNoToken: 1 };
    }

    // Defense in depth: the sweep only calls this for hour-20 buckets, which are
    // outside quiet hours — but re-check on the SAME instant/zone so the delivery
    // function can never emit inside 22:00–08:00 regardless of its caller.
    if (isQuietLocalHour(localHour(at, timezone))) {
      logger.info('question_rollover: at-risk push suppressed, couple-local quiet hours', { recipientUid });
      return { ...base, status: 'suppressed-quiet-hours', suppressedQuiet: 1 };
    }

    const language = contentLanguageOf(userData);
    // No question/answer text EVER leaves in a payload (ADR-012 F6); discreet mode
    // defaults ON for AR recipients. streakCount tunes only the non-discreet copy.
    const payload = composePush({
      kind: 'streakAtRisk',
      language,
      discreet: resolveDiscreet(language),
      streakCount,
    });

    let sent = 0;
    let failed = 0;
    for (const token of tokens) {
      try {
        await messaging.send({ token, title: payload.title, body: payload.body });
        sent += 1;
      } catch (error) {
        failed += 1;
        logger.error('question_rollover: at-risk push send failed', {
          recipientUid,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    return { ...base, status: sent > 0 ? 'sent' : 'send-failed', sent, failed };
  } catch (error) {
    // Any unexpected failure resolving the recipient (a corrupt uid path segment,
    // a read error): the sweep must survive it as a counted noise, never a throw.
    logger.error('question_rollover: at-risk push delivery errored', {
      recipientUid,
      error: error instanceof Error ? error.message : String(error),
    });
    return { ...base, status: 'send-failed', failed: 1 };
  }
}

/**
 * The members of `member` who have NOT answered today (the at-risk recipients).
 * Reads BOTH answer docs in one round trip for an ELIGIBLE couple only (O(1) reads
 * per eligible couple, once per day, hour-20 bucket only — architecture §10 shape
 * unchanged). memberUids is the M2.3 join Function's write (a 2-element uid array);
 * anything else here is corrupt state the caller turns into a per-couple skip.
 */
async function nonAnswerers(db: Firestore, coupleId: string, memberUids: unknown, dayKey: string): Promise<string[]> {
  if (!Array.isArray(memberUids) || !memberUids.every((u): u is string => typeof u === 'string')) {
    throw new Error(`couple ${coupleId}: malformed memberUids`);
  }
  const answersCol = db
    .collection('couples')
    .doc(coupleId)
    .collection('days')
    .doc(dayKey)
    .collection('answers');
  const snaps = await db.getAll(...memberUids.map((uid) => answersCol.doc(uid)));
  // Match by doc id, not array position — getAll order is not a contract to lean on.
  const answered = new Set(snaps.filter((s) => s.exists).map((s) => s.id));
  return memberUids.filter((uid) => !answered.has(uid));
}

/**
 * The at-risk push pass over the shared timezone buckets (ADR-012 D3). Iterates the
 * SAME buckets the assignment pass used — zero extra couples reads. For each bucket
 * whose sweep-local hour is 20, checks each couple's stored streak (no read — it
 * rides on the couple doc already in the bucket) and, for those with something to
 * lose, reads today's day doc (one read/couple) to gate on "exists AND unrevealed",
 * then nudges the non-answerer(s). Every per-couple/per-send problem is a logged
 * skip counted in the summary; the pass never throws for a single couple (a
 * systemic throw is caught and isolated by the handler, never failing assignment).
 */
export async function runStreakAtRisk(
  db: Firestore,
  at: Date,
  messaging: MessagingPort,
  coupleBuckets: CoupleBuckets,
): Promise<AtRiskSummary> {
  const summary: AtRiskSummary = {
    checked: 0,
    sent: 0,
    skippedNoToken: 0,
    skippedNoDay: 0,
    suppressedQuiet: 0,
    failed: 0,
  };

  for (const [timezone, members] of coupleBuckets.buckets) {
    let hour: number;
    let dayKey: string;
    try {
      hour = localHour(at, timezone);
      dayKey = localDayKey(at, timezone);
    } catch {
      // Corrupt stored zone (non-IANA): the assignment pass already logged+counted
      // these couples as skips — the at-risk pass simply cannot evaluate them.
      continue;
    }
    if (hour !== AT_RISK_LOCAL_HOUR) {
      continue; // not this zone's evening sweep — once per zone per day (ADR-012 D3).
    }

    for (const member of members) {
      try {
        // streak rides on the couple doc already read into the bucket — no read here.
        const streak = parseStreak(member.data.streak);
        if (streak.count <= 0) {
          continue; // nothing to lose (zero or absent streak) — not at-risk.
        }

        const daySnap = await db
          .collection('couples')
          .doc(member.coupleId)
          .collection('days')
          .doc(dayKey)
          .get();
        if (!daySnap.exists) {
          // streak > 0 but rollover never assigned today's question for this couple:
          // there is nothing to answer, so this is NOT an at-risk state (ADR-012 D3).
          summary.skippedNoDay += 1;
          continue;
        }
        if (daySnap.get('revealedAt') != null) {
          continue; // already mutually revealed today — the healthy case, nothing to nudge.
        }

        // Eligible: streak > 0 AND today's day doc exists unrevealed.
        summary.checked += 1;
        const recipients = await nonAnswerers(db, member.coupleId, member.data.memberUids, dayKey);
        for (const recipientUid of recipients) {
          const outcome = await deliverAtRiskPush(db, messaging, recipientUid, streak.count, timezone, at);
          summary.sent += outcome.sent;
          summary.skippedNoToken += outcome.skippedNoToken;
          summary.suppressedQuiet += outcome.suppressedQuiet;
          summary.failed += outcome.failed;
        }
      } catch (error) {
        // A single corrupt couple (malformed members, read error) is a logged skip
        // that never fails the sweep (ADR-012 D3 — the per-couple error boundary).
        summary.failed += 1;
        logger.error('question_rollover: at-risk couple skipped', {
          coupleId: member.coupleId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }
  return summary;
}
