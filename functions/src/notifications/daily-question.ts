// The daily-question push pass (ADR-042 Decision 3) — the founder's first ask,
// verbatim: "It needs to be send new questions at 08.00 TSI with a question."
//
// PIGGYBACKED on the hourly questionRollover sweep, never a second scheduled
// Function. The sweep lists every couple ONCE and buckets them by stored timezone;
// this pass reuses that SAME snapshot, exactly as the at-risk pass does. ADR-012
// D3's hard constraint is one couples-collection read per production sweep and
// ADR-042 does NOT amend it — a third pass is one more argument to the handler's
// existing `bucket(db)`, not a new machine.
//
// "08.00 TSİ" was read as 08:00 COUPLE-LOCAL — and ADR-045 later re-pointed the
// hour itself to 9 (founder, 2026-08-10). The COUPLE-LOCAL reading is the part
// that survived, and it is the load-bearing one. It is TSİ for the founder couple, and
// every other time decision in this system runs off the couple's stored timezone
// rather than a fixed offset (localHour, localDayKey, ADR-011). A literal
// Europe/Istanbul constant would be correct for exactly one couple and silently
// wrong for the Gulf-Arabic audience the product is built for.
import { Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { localDayKey } from '../rollover/day-key';
import type { CoupleBuckets } from '../rollover/rollover-service';
import { localHour } from './local-hour';
import type { MessagingPort } from './messaging-port';
import { deliverSweepPush, nonAnswerers } from './sweep-push';

/**
 * The couple-LOCAL wall-clock hour the daily-question push fires on — **9**
 * since ADR-045 (founder, 2026-08-10: *"questions should be sent at 9:00 AM"*),
 * re-pointed from the 8 ADR-042 D3 chose. Once per zone per day: only the sweep
 * whose bucket-local hour reads 9 pushes.
 *
 * **What moved and what deliberately did NOT.** Only the ANNOUNCEMENT moved. The
 * rollover still assigns the day's question at local **midnight**, so the app
 * shows the new question to anyone who opens it before 09:00 — the founder chose
 * that explicitly over moving the assignment, because `dayKey`, the streak, the
 * reveal and this pass are all keyed on the local-midnight boundary and moving it
 * would have created a nine-hour window with no question and no defined state.
 *
 * **9 is no longer adjacent to the quiet window, and that is a small win.** Under
 * ADR-042 D3 this constant sat exactly on the 08:00 boundary — the first legal
 * hour — where a one-hour drift in either the window or the constant silently
 * killed the feature. At 9 there is an hour of slack on this side. The fragile
 * end has MOVED, not vanished: it is now the 22:00 nudge sitting against the new
 * 23:00 window edge (`at-risk.ts`), and it is asserted there.
 *
 * Sub-hour-offset zones (Asia/Kathmandu +05:45) land on the hourly sweep whose
 * local clock reads 09:xx, exactly as their midnight bucket does.
 */
export const DAILY_QUESTION_LOCAL_HOUR = 9;

/** The daily-question sweep counters the handler logs and the tests assert on. */
export interface DailyQuestionSummary {
  /** Couples with today's day doc present and unrevealed — i.e. something to announce. */
  checked: number;
  /** Announcements delivered (≥1 token accepted by the port). */
  sent: number;
  /** Recipients with no fcm token — a loud skip (expected until the device slice). */
  skippedNoToken: number;
  /** Couples with NO day doc for today: rollover failed at local midnight, nine
   *  hours before this pass, so there is no question to announce. Counted
   *  separately because it is an assignment failure surfacing here, not a push one. */
  skippedNoDay: number;
  /** Sends dropped by the defense-in-depth quiet-hours check. MUST be 0 at hour 9
   *  — a non-zero value here means the boundary moved and the feature is dead. */
  suppressedQuiet: number;
  /** Per-token send failures + per-couple processing errors, all swallowed. */
  failed: number;
}

/**
 * The daily-question pass over the shared timezone buckets (ADR-042 D3).
 *
 * For each bucket whose sweep-local hour is 9, reads today's day doc (one read per
 * couple) and announces the new question to whichever members have not already
 * answered it. Every per-couple/per-send problem is a logged skip counted in the
 * summary; the pass never throws for a single couple.
 *
 * **Why non-answerers rather than both members.** At local 09:00 the day doc was
 * created nine hours earlier at local midnight, so in the ordinary case nobody
 * has answered and both get it. But an early bird who already answered does not
 * need to be told a question exists — announcing it to them is the small kind of
 * wrongness that makes an app feel like it is not paying attention. The cost is
 * one `getAll` of two answer docs per eligible couple, the same shape the at-risk
 * pass already pays; recorded in ADR-012 §10.
 */
export async function runDailyQuestion(
  db: Firestore,
  at: Date,
  messaging: MessagingPort,
  coupleBuckets: CoupleBuckets,
): Promise<DailyQuestionSummary> {
  const summary: DailyQuestionSummary = {
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
      // these couples as skips — this pass simply cannot evaluate them.
      continue;
    }
    if (hour !== DAILY_QUESTION_LOCAL_HOUR) {
      continue; // not this zone's morning sweep — once per zone per day.
    }

    for (const member of members) {
      try {
        const daySnap = await db
          .collection('couples')
          .doc(member.coupleId)
          .collection('days')
          .doc(dayKey)
          .get();
        if (!daySnap.exists) {
          summary.skippedNoDay += 1;
          continue;
        }
        if (daySnap.get('revealedAt') != null) {
          // Both answered already — between local midnight and local 09:00, which
          // is rare but legal. There is nothing new to announce.
          continue;
        }

        summary.checked += 1;
        const recipients = await nonAnswerers(db, member.coupleId, member.data.memberUids, dayKey);
        for (const recipientUid of recipients) {
          const outcome = await deliverSweepPush(
            db,
            messaging,
            recipientUid,
            'dailyQuestion',
            timezone,
            at,
          );
          summary.sent += outcome.sent;
          summary.skippedNoToken += outcome.skippedNoToken;
          summary.suppressedQuiet += outcome.suppressedQuiet;
          summary.failed += outcome.failed;
        }
      } catch (error) {
        // A single corrupt couple (malformed memberUids, read error) is a logged
        // skip that never fails the sweep — the per-couple error boundary.
        summary.failed += 1;
        logger.error('question_rollover: daily-question couple skipped', {
          coupleId: member.coupleId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }
  return summary;
}
