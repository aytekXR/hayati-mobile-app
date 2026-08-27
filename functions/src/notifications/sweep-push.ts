// The delivery half shared by every push pass that rides the hourly sweep
// (ADR-012 D3, ADR-042 D3/D4). Extracted from at-risk.ts when the daily-question
// pass arrived: the two passes differ in WHICH couples they select and WHICH kind
// they compose, and in nothing else. Duplicating the recipient resolution, the
// quiet-hours guard and the per-token error boundary would have left two copies of
// the code that decides whether a lock screen leaks — and only one of them would
// get the next fix.
//
// NOTHING here throws. A push that cannot go out must never fail a sweep whose
// real job is assigning tomorrow's question.
import { Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { isQuietLocalHour, localHour } from './local-hour';
import type { MessagingPort } from './messaging-port';
import { PushKind, composePush } from './payload-policy';
import {
  contentLanguageOf,
  fcmTokensOf,
  notificationPrivacyOf,
  resolveDiscreet,
} from './recipients';

/** Terminal state of one recipient's best-effort send; every field is a summary increment. */
export interface SweepPushOutcome {
  status: 'sent' | 'no-tokens' | 'suppressed-quiet-hours' | 'send-failed';
  sent: number;
  skippedNoToken: number;
  suppressedQuiet: number;
  failed: number;
}

/**
 * Resolve one recipient and best-effort send `kind`. Every branch short of a
 * delivered send is a TYPED, LOGGED skip whose numeric fields the caller folds
 * straight into its summary (no per-status switch, so aggregation stays
 * branch-free). `at` is the sweep instant, used as the clock for the quiet-hours
 * guard.
 *
 * The quiet-hours check is DEFENSE IN DEPTH, and it is the reason this function
 * takes the timezone rather than trusting its caller: each pass already gates on
 * its own local hour, but the delivery function must be unable to emit inside
 * **23:00–08:00** no matter who calls it or from which pass.
 *
 * ⚠️ THIS PARAGRAPH NAMED THE WRONG PASS AND THE WRONG WINDOW until 2026-08-28.
 * It said the guard was load-bearing "for the daily-question pass in particular,
 * which fires at hour 8 — the first legal hour". ADR-045 moved that pass to **9**,
 * an hour clear of the boundary, and moved the window itself to 23:00–08:00. The
 * fragile end did not vanish, it MOVED: it is now the **22:00 nudge** sitting
 * against the 23:00 edge (`at-risk.ts`, which has said so since ADR-045 while
 * this comment said the opposite). Move `AT_RISK_LOCAL_HOUR` or
 * `isQuietLocalHour` by one in either direction and the nudge dies silently with
 * every unrelated test green.
 */
export async function deliverSweepPush(
  db: Firestore,
  messaging: MessagingPort,
  recipientUid: string,
  kind: PushKind,
  timezone: string,
  at: Date,
  options: { streakCount?: number } = {},
): Promise<SweepPushOutcome> {
  const base = { sent: 0, skippedNoToken: 0, suppressedQuiet: 0, failed: 0 } as const;
  try {
    const userSnap = await db.collection('users').doc(recipientUid).get();
    // A missing user doc and an empty/junk fcmTokens field collapse to the same
    // "nothing to send to" skip (ADR-012: fcmTokensOf → [] on absent/malformed).
    const userData = userSnap.exists ? userSnap.data() : undefined;
    const tokens = fcmTokensOf(userData);
    if (tokens.length === 0) {
      logger.warn('question_rollover: sweep push skipped, no fcm tokens', { recipientUid, kind });
      return { ...base, status: 'no-tokens', skippedNoToken: 1 };
    }

    if (isQuietLocalHour(localHour(at, timezone))) {
      logger.info('question_rollover: sweep push suppressed, couple-local quiet hours', {
        recipientUid,
        kind,
      });
      return { ...base, status: 'suppressed-quiet-hours', suppressedQuiet: 1 };
    }

    const language = contentLanguageOf(userData);
    // No question/answer text EVER leaves in a payload (ADR-012 F6, structural —
    // composePush has no such parameter); discreet mode defaults ON for AR.
    const payload = composePush({
      kind,
      language,
      discreet: resolveDiscreet(language, notificationPrivacyOf(userData)),
      streakCount: options.streakCount,
    });

    let sent = 0;
    let failed = 0;
    for (const token of tokens) {
      try {
        await messaging.send({ token, title: payload.title, body: payload.body });
        sent += 1;
      } catch (error) {
        failed += 1;
        logger.error('question_rollover: sweep push send failed', {
          recipientUid,
          kind,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    return { ...base, status: sent > 0 ? 'sent' : 'send-failed', sent, failed };
  } catch (error) {
    // Any unexpected failure resolving the recipient (a corrupt uid path segment,
    // a read error): the sweep must survive it as counted noise, never a throw.
    logger.error('question_rollover: sweep push delivery errored', {
      recipientUid,
      kind,
      error: error instanceof Error ? error.message : String(error),
    });
    return { ...base, status: 'send-failed', failed: 1 };
  }
}

/**
 * The members of `memberUids` who have NOT answered on `dayKey`.
 *
 * Reads BOTH answer docs in one round trip, for an ELIGIBLE couple only — O(1)
 * reads per eligible couple per pass. memberUids is the M2.3 join Function's write
 * (a 2-element uid array); anything else is corrupt state the caller turns into a
 * per-couple skip.
 */
export async function nonAnswerers(
  db: Firestore,
  coupleId: string,
  memberUids: unknown,
  dayKey: string,
): Promise<string[]> {
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
