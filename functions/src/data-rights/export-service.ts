// The Firestore + Auth read half of the M6.2 self-serve export (ADR-019
// Decision 5). `db` is injected by the shell. Assembles the versioned export
// document strictly from the requester's own data: profile + Auth record, solo
// answers, couple context (never memberUids), ONLY answers/{A}, the requester's
// own coach daily lane, the subscription summary + lanes[A] only, and invites
// naming A with the counterpart uid scrubbed. All the scrubbing rules are the pure
// projections in data-rights-core; this module only reads and composes.
import { getAuth } from 'firebase-admin/auth';
import { Firestore } from 'firebase-admin/firestore';

import {
  AuthProfile,
  EXPORT_QUESTION_NOTE,
  ExportCoupleAnswer,
  ExportCoupleContext,
  ExportDailyLane,
  ExportEnvelope,
  ExportInvite,
  ExportSubscription,
  FORMAT_VERSION,
  projectCoupleAnswer,
  projectCoupleContext,
  projectDailyLane,
  projectInvite,
  projectProfile,
  projectSoloAnswer,
  projectSubscription,
} from './data-rights-core';

export type ExportResult =
  | { kind: 'ok'; document: ExportEnvelope }
  | { kind: 'profile-missing' };

export interface ExportDeps {
  /** Injectable clock (default Date.now) → generatedAt, for deterministic tests. */
  now?: () => number;
  /** Auth-record lookup (default getAuth().getUser); null when the record is gone. */
  authLookup?: (uid: string) => Promise<AuthProfile | null>;
}

/** Production Auth lookup: displayName/email/photoURL, null on any failure. */
const defaultAuthLookup = (uid: string): Promise<AuthProfile | null> =>
  getAuth()
    .getUser(uid)
    .then((user) => ({
      displayName: user.displayName ?? null,
      email: user.email ?? null,
      photoURL: user.photoURL ?? null,
    }))
    .catch(() => null);

/**
 * Builds the export document for `uid` (Decision 5). A missing requester profile
 * is a typed `profile-missing` (the shell maps it to failed-precondition — the
 * Decision 2 callable-surface rule); everything else assembles from the reads.
 */
export async function buildExportDocument(
  db: Firestore,
  uid: string,
  deps: ExportDeps = {},
): Promise<ExportResult> {
  const now = deps.now ?? Date.now;
  const authLookup = deps.authLookup ?? defaultAuthLookup;

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    return { kind: 'profile-missing' };
  }
  const userData = userSnap.data() ?? {};

  const authProfile = await authLookup(uid);
  const profile = projectProfile(userData, authProfile);

  const soloSnaps = await userRef.collection('soloAnswers').get();
  const soloAnswers = soloSnaps.docs.map((snap) =>
    projectSoloAnswer(snap.id, snap.data()),
  );

  let coupleContext: ExportCoupleContext | null = null;
  const coupleAnswers: ExportCoupleAnswer[] = [];
  let coachDaily: ExportDailyLane | null = null;
  let subscription: ExportSubscription | null = null;

  const rawCoupleId = userData.coupleId;
  const coupleId =
    typeof rawCoupleId === 'string' && rawCoupleId.length > 0 ? rawCoupleId : null;

  if (coupleId !== null) {
    const coupleRef = db.collection('couples').doc(coupleId);
    const coupleSnap = await coupleRef.get();
    if (coupleSnap.exists) {
      const coachUsageRef = db.collection('coachUsage').doc(coupleId);
      const coachUsageSnap = await coachUsageRef.get();
      coupleContext = projectCoupleContext(
        coupleId,
        coupleSnap.data() ?? {},
        coachUsageSnap.exists ? coachUsageSnap.data() : undefined,
      );

      // ONLY answers/{A}: B-authored docs are never even read (Decision 5).
      const dayRefs = await coupleRef.collection('days').listDocuments();
      for (const dayRef of dayRefs) {
        const [daySnap, answerSnap] = await Promise.all([
          dayRef.get(),
          dayRef.collection('answers').doc(uid).get(),
        ]);
        if (answerSnap.exists) {
          coupleAnswers.push(
            projectCoupleAnswer(
              dayRef.id,
              daySnap.exists ? daySnap.data() : undefined,
              answerSnap.data() ?? {},
            ),
          );
        }
      }

      const dailySnap = await coachUsageRef.collection('daily').doc(uid).get();
      coachDaily = dailySnap.exists ? projectDailyLane(dailySnap.data() ?? {}) : null;

      const subSnap = await db.collection('subscriptions').doc(coupleId).get();
      subscription = subSnap.exists
        ? projectSubscription(subSnap.data() ?? {}, uid)
        : null;
    }
  }

  const invitesCol = db.collection('invites');
  const [created, joined] = await Promise.all([
    invitesCol.where('creatorUid', '==', uid).get(),
    invitesCol.where('joinerUid', '==', uid).get(),
  ]);
  const inviteMap = new Map<string, ExportInvite>();
  for (const snap of [...created.docs, ...joined.docs]) {
    inviteMap.set(snap.id, projectInvite(snap.id, snap.data(), uid));
  }

  const document: ExportEnvelope = {
    formatVersion: FORMAT_VERSION,
    generatedAt: new Date(now()).toISOString(),
    uid,
    data: {
      profile,
      soloAnswers,
      coupleContext,
      coupleAnswers,
      coachUsage: { daily: coachDaily },
      subscription,
      invites: [...inviteMap.values()],
      note: EXPORT_QUESTION_NOTE,
    },
  };
  return { kind: 'ok', document };
}
