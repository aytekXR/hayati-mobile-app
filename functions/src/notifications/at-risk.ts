// The unanswered-day nudge — PIGGYBACKED on the hourly questionRollover sweep
// (ADR-012 Decision 3), never a second scheduled Function. The sweep lists every
// couple ONCE and buckets them by stored timezone; this pass reuses that SAME
// snapshot, so it adds zero couples reads.
//
// ⚠️ ADR-042 D4 CHANGED WHAT THIS PASS IS FOR, and the file name lags the meaning.
// It used to protect a STREAK: hour 20, and only couples with `streak.count > 0`.
// The founder asked for something else — "If you did not reply the question as of
// 16.00 you need to be notified so that your partner dont get angry" — which
// protects a RELATIONSHIP and must therefore fire for a couple with NO streak at
// all. That is most couples in week one and every couple that ever broke one.
//
// So: hour 20 → 16, and the streak gate is GONE. The streak count still tunes the
// copy when a streak exists; when it does not, composePush returns a different
// message rather than streak copy with the digits removed (payload-policy.ts).
//
// Re-pointed rather than duplicated: the 16:00 population is a strict SUPERSET of
// the 20:00 one, so nothing is lost, and a second afternoon hour would give a
// couple with a streak two pushes in one evening. ADR-012 D3 deliberately has no
// dedup state — double-sends are structurally absent, not guarded — so adding an
// hour would have created exactly the class of duplicate that design avoids.
import { Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { localDayKey } from '../rollover/day-key';
import type { CoupleBuckets } from '../rollover/rollover-service';
import { parseStreak } from '../streak/streak';
import { localHour } from './local-hour';
import type { MessagingPort } from './messaging-port';
import { SweepPushOutcome, deliverSweepPush, nonAnswerers } from './sweep-push';

// The couple-LOCAL wall-clock hour the nudge fires on (ADR-042 D4, re-pointed from
// 20): once per zone per day — only the sweep whose bucket-local hour reads 16
// pushes. 16 is comfortably OUTSIDE the 22:00–08:00 quiet window (deliverSweepPush
// re-checks anyway, defense in depth), unlike the daily-question pass at hour 8
// which sits exactly on the boundary. Sub-hour-offset zones (Asia/Kathmandu +05:45)
// land on the hourly sweep whose local clock reads 16:xx, exactly as their midnight
// bucket does. DST transitions never occur at 16:xx in practice.
export const AT_RISK_LOCAL_HOUR = 16;

/** The at-risk sweep counters the handler logs and the tests assert on. */
export interface AtRiskSummary {
  /** Eligible couples (today's day doc exists and is unrevealed). Since ADR-042 D4
   *  there is NO streak precondition — the nudge protects the relationship, not the
   *  counter, so a couple with no streak is exactly who it is for. */
  checked: number;
  /** At-risk pushes delivered (≥1 token accepted by the port). */
  sent: number;
  /** Recipients with no fcm token — a loud skip (expected pre-on-device capture). */
  skippedNoToken: number;
  /** Couples with NO day doc for today (rollover failed earlier — nothing to
   *  answer, so NOT an at-risk state; counted separately). */
  skippedNoDay: number;
  /** Sends dropped by the defense-in-depth quiet-hours check (0 at hour 16 by
   *  construction; the counter exists so the guard is observable if it ever fires). */
  suppressedQuiet: number;
  /** Per-token send failures + per-couple processing errors, all swallowed. */
  failed: number;
}

/**
 * Thin wrapper over the shared sweep delivery (sweep-push.ts), kept as a named
 * export because the at-risk suite exercises the delivery branches through it.
 * The recipient resolution, the defense-in-depth quiet guard and the per-token
 * error boundary are IDENTICAL across passes and now live in one place — two
 * copies of the code that decides whether a lock screen leaks would have meant
 * only one of them getting the next fix.
 */
export async function deliverAtRiskPush(
  db: Firestore,
  messaging: MessagingPort,
  recipientUid: string,
  streakCount: number,
  timezone: string,
  at: Date,
): Promise<SweepPushOutcome> {
  return deliverSweepPush(db, messaging, recipientUid, 'streakAtRisk', timezone, at, {
    streakCount,
  });
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
        // streak rides on the couple doc already read into the bucket — no read
        // here. It no longer GATES anything (ADR-042 D4 dropped `count > 0`); it
        // only tunes the copy, and a zero/absent streak yields the relationship
        // nudge instead of streak copy.
        const streak = parseStreak(member.data.streak);

        const daySnap = await db
          .collection('couples')
          .doc(member.coupleId)
          .collection('days')
          .doc(dayKey)
          .get();
        if (!daySnap.exists) {
          // Rollover never assigned today's question for this couple: there is
          // nothing to answer, so this is NOT an at-risk state (ADR-012 D3).
          summary.skippedNoDay += 1;
          continue;
        }
        if (daySnap.get('revealedAt') != null) {
          continue; // already mutually revealed today — the healthy case, nothing to nudge.
        }

        // Eligible: today's day doc exists and is unrevealed. No streak clause —
        // see the file header and ADR-042 D4.
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
