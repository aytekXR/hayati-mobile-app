// The partner-preview question hook (PRD F1 restore; redesign ui-ux §5.3):
// the invite preview grows `questionText` + `creatorAnswered` — today's solo
// question on the inviter's side and whether they have already answered it.
// "{name} has already answered. Their answer unlocks when you write yours."
// is the single most Gate-2-relevant line in the app; the preview projection
// was designed to grow exactly this (invite-preview.ts).
//
// PRIVACY: the hook exposes QUESTION TEXT (bundled public content) and one
// boolean — never answer content, never a dayKey, never anything from the
// answer doc but its existence. The §4 invariant "preview never leaks answer
// content" holds by construction: the projection in invite-preview.ts is
// still the only place response fields are assembled.
//
// HONEST BOUND (documented, not hidden): the inviter's solo day is a LOCAL
// calendar computation on their device (solo_day.dart), and the server does
// not know their timezone. The hook therefore (a) treats the inviter's
// LATEST solo answer as "answered today" when its dayKey falls within ±1 UTC
// calendar day of now — a window that covers every real timezone
// (UTC-12…UTC+14) and can only over-report near the inviter's midnight by
// showing the question they answered moments ago, and (b) falls back to the
// UTC-computed day-N question with `creatorAnswered: false` otherwise. Near
// date boundaries the fallback question can be one day off the inviter's
// device view; the preview is a pitch, not a ledger, and it never claims an
// answer it cannot pair with its question.
import type { Firestore, Timestamp } from 'firebase-admin/firestore';
import { FieldPath } from 'firebase-admin/firestore';

import { type QuestionPack, loadQuestionPack } from '../rollover/pack-loader';

/** The solo cycle length — must mirror the app's `soloQuestionDays`. */
export const SOLO_QUESTION_DAYS = 7;

const SOLO_LOCALES = new Set(['tr', 'ar', 'en']);

/** What the hook projects into the preview (see invite-preview.ts). */
export interface CreatorQuestionHook {
  questionText: string;
  creatorAnswered: boolean;
}

/** The inviter-side inputs the pure core decides from. */
export interface CreatorQuestionInputs {
  /** `users/{uid}.contentLanguage` as stored (validated here, fail-soft). */
  contentLanguage: unknown;
  /** `users/{uid}.createdAt` as a Date, or undefined while pending/absent. */
  createdAt: Date | undefined;
  /** The latest `soloAnswers` doc (max dayKey), or undefined when none. */
  latestAnswer: { dayKey: string; questionId: unknown } | undefined;
  /** The bundled solo pack for the creator's content language. */
  pack: QuestionPack;
  /** The server clock. */
  now: Date;
}

/** yyyymmdd of `date`'s UTC calendar date (the app's soloDayKey shape). */
export function utcDayKey(date: Date): string {
  return (
    date.getUTCFullYear().toString().padStart(4, '0') +
    (date.getUTCMonth() + 1).toString().padStart(2, '0') +
    date.getUTCDate().toString().padStart(2, '0')
  );
}

/**
 * 1-based solo day, the app's `soloDayNumber` mirrored onto UTC date
 * components: calendar-date distance, day 1 on the anchor's date, clamped to
 * 1 for a missing/future anchor (the honest floor, never a crash).
 */
export function soloDayNumberUtc(anchor: Date | undefined, now: Date): number {
  if (anchor === undefined) return 1;
  const days =
    Math.floor(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) / 86_400_000) -
    Math.floor(
      Date.UTC(anchor.getUTCFullYear(), anchor.getUTCMonth(), anchor.getUTCDate()) / 86_400_000,
    );
  return days < 0 ? 1 : days + 1;
}

/** The ±1-UTC-day window that covers every real timezone's "today". */
export function todayWindowKeys(now: Date): Set<string> {
  const day = 86_400_000;
  return new Set([
    utcDayKey(new Date(now.getTime() - day)),
    utcDayKey(now),
    utcDayKey(new Date(now.getTime() + day)),
  ]);
}

/**
 * Pure hook decision (unit-tested without Firestore):
 *
 *  1. an off-vocabulary contentLanguage → no hook (fail-soft: a valid invite
 *     never degrades over a hook input);
 *  2. the latest answer is "today" (±1 UTC day) AND its questionId resolves
 *     in the pack → that question + `creatorAnswered: true` — the strongest
 *     honest form of the PRD line, keyed by what they actually answered;
 *  3. otherwise the UTC day-N question + `creatorAnswered: false`, while the
 *     solo cycle is still running (day ≤ 7);
 *  4. day 8+ with no today-answer → no hook (the cycle is complete; there is
 *     no honest "today's question" to promise).
 */
export function creatorQuestionHook(
  inputs: CreatorQuestionInputs,
): CreatorQuestionHook | undefined {
  const { contentLanguage, createdAt, latestAnswer, pack, now } = inputs;
  if (typeof contentLanguage !== 'string' || !SOLO_LOCALES.has(contentLanguage)) {
    return undefined;
  }
  if (latestAnswer !== undefined && todayWindowKeys(now).has(latestAnswer.dayKey)) {
    const question = pack.questions.find((q) => q.id === latestAnswer.questionId);
    if (question !== undefined) {
      return { questionText: question.text, creatorAnswered: true };
    }
    // A today-answer whose question we cannot show falls through to the
    // fallback: never claim "answered" for a question that is not on screen.
  }
  const day = soloDayNumberUtc(createdAt, now);
  if (day > SOLO_QUESTION_DAYS) return undefined;
  const question = pack.questions[day - 1];
  if (question === undefined) return undefined;
  return { questionText: question.text, creatorAnswered: false };
}

/** Injectable lookup seam, mirroring invite-preview's `CreatorNameLookup`. */
export type CreatorQuestionLookup = (
  db: Firestore,
  creatorUid: string,
) => Promise<CreatorQuestionHook | undefined>;

/**
 * Production lookup: gathers the creator's profile fields, their latest solo
 * answer (max dayKey — doc ids sort chronologically) and the bundled solo
 * pack for their content language, then defers to the pure core. Any throw
 * (absent profile fields are handled; a missing/corrupt PACK throws) is
 * swallowed by `previewInvite` — a hook failure never downgrades a valid
 * invite, exactly like the name lookup.
 */
export async function resolveCreatorQuestionHook(
  db: Firestore,
  creatorUid: string,
  loadPack: typeof loadQuestionPack = loadQuestionPack,
  now: () => Date = () => new Date(),
): Promise<CreatorQuestionHook | undefined> {
  const at = now();
  const userRef = db.collection('users').doc(creatorUid);
  // The ±1-UTC-day window as an ASCENDING documentId range, not a descending
  // max-key scan: the firestore EMULATOR rejects `orderBy(documentId, desc)`
  // outright ("Firestore does not support descending key scans", code 9), and
  // the pure core ignores an out-of-window latest answer anyway — so querying
  // only the window is semantically identical, emulator-safe, and bounded to
  // ≤3 docs. Ids sort ascending by default; the last doc is the max in window.
  const day = 86_400_000;
  const [userSnap, windowSnap] = await Promise.all([
    userRef.get(),
    userRef
      .collection('soloAnswers')
      .where(FieldPath.documentId(), '>=', utcDayKey(new Date(at.getTime() - day)))
      .where(FieldPath.documentId(), '<=', utcDayKey(new Date(at.getTime() + day)))
      .get(),
  ]);
  if (!userSnap.exists) return undefined;
  const contentLanguage: unknown = userSnap.get('contentLanguage');
  if (typeof contentLanguage !== 'string' || !SOLO_LOCALES.has(contentLanguage)) {
    return undefined;
  }
  const createdAtRaw: unknown = userSnap.get('createdAt');
  const createdAt =
    createdAtRaw !== null &&
    typeof createdAtRaw === 'object' &&
    typeof (createdAtRaw as Timestamp).toDate === 'function'
      ? (createdAtRaw as Timestamp).toDate()
      : undefined;
  const latestDoc = windowSnap.docs[windowSnap.docs.length - 1];
  const latestAnswer =
    latestDoc === undefined
      ? undefined
      : { dayKey: latestDoc.id, questionId: latestDoc.get('questionId') as unknown };
  return creatorQuestionHook({
    contentLanguage,
    createdAt,
    latestAnswer,
    pack: loadPack(`solo_${contentLanguage}`),
    now: at,
  });
}
