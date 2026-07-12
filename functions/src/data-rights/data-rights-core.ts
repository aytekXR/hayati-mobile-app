// Pure decision core for the M6.2 data-rights callables (ADR-019 Decisions
// 2/5/6). All total functions over plain values — no Firestore, no I/O — so the
// request validation, the export projection/scrubbing rules, and the PII-safe log
// shape are exhaustively unit-testable without the emulator (the coach-core.ts
// mold). The stage-2 services (deletion-service / export-service /
// notification-privacy-service) drive the Firestore work and call these; this
// module owns WHAT the rules are: exactly what leaves in an export, and exactly
// what a deletion event may (never) log.

/** The export document version (Decision 5). A shape change bumps this. */
export const FORMAT_VERSION = 1;

/**
 * The wire-level literal the app sends on the deleteAccount request (Decision 2).
 * It is NEVER typed by a user (no localization/screen-reader surface), so no
 * client bug can invoke deletion by accident.
 */
export const DELETE_CONFIRM = 'DELETE';

/** A note carried in every export: question wording is by-id, never duplicated. */
export const EXPORT_QUESTION_NOTE =
  'Question text is referenced by questionId only; the full wording lives in the ' +
  "app's bundled question packs and is not duplicated in this export.";

// --- shared defensive readers -----------------------------------------------

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function asStringOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function asNumberOrNull(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/**
 * Epoch-ms from a Firestore Timestamp (duck-typed on `toMillis`), a raw number,
 * or null for anything else. Duck-typing keeps the projections pure — a unit test
 * passes a plain `{ toMillis: () => n }` or a number, never a real Timestamp.
 */
function toMillis(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (value !== null && typeof value === 'object') {
    const candidate = (value as { toMillis?: unknown }).toMillis;
    if (typeof candidate === 'function') {
      const ms = (candidate as () => unknown).call(value);
      return typeof ms === 'number' && Number.isFinite(ms) ? ms : null;
    }
  }
  return null;
}

// --- deleteAccount request validation (Decision 2) --------------------------

export type DeleteValidation =
  | { ok: true }
  | { ok: false; reason: 'not-object' | 'bad-confirm' };

/**
 * The deleteAccount body must be an object carrying `confirm: 'DELETE'` verbatim
 * (Decision 2). Anything else → a static, enumerated reason the shell maps to
 * `invalid-argument` (no interpolation of request content).
 */
export function validateDeleteRequest(body: unknown): DeleteValidation {
  if (!isRecord(body)) {
    return { ok: false, reason: 'not-object' };
  }
  if (body.confirm !== DELETE_CONFIRM) {
    return { ok: false, reason: 'bad-confirm' };
  }
  return { ok: true };
}

// --- updateNotificationPrivacy request validation (Decision 6) --------------

export type NotificationPrivacyValidation =
  | { ok: true; discreet: boolean }
  | { ok: false };

/** The override request body: `{ discreet: boolean }`, nothing else accepted. */
export function validateNotificationPrivacyRequest(
  body: unknown,
): NotificationPrivacyValidation {
  if (!isRecord(body) || typeof body.discreet !== 'boolean') {
    return { ok: false };
  }
  return { ok: true, discreet: body.discreet };
}

// --- cascade steps (Decision 2) ---------------------------------------------

/**
 * The pinned cascade steps (Decision 2). The service takes an injectable
 * `checkpoint(step)` and calls it after EACH — including the explicit one around
 * the non-transactional auth delete — so the resumability tests can kill after
 * any step and prove the re-drive converges.
 */
export type CascadeStep =
  | 'resolve'
  | 'detach'
  | 'couple-sweep'
  | 'invites-sweep'
  | 'own-sweep'
  | 'remove-cursor'
  | 'auth-delete';

// --- PII-safe logging (Decision 2 / ADR-016 D8) -----------------------------

export type DataRightsOp =
  | 'deleteAccount'
  | 'exportData'
  | 'updateNotificationPrivacy';

export type DataRightsOutcome =
  | 'deleted'
  | 'exported'
  | 'updated'
  | 'unauthenticated'
  | 'invalid'
  | 'profile-missing'
  | 'internal';

/**
 * The ONLY fields a data-rights log line may carry. There is deliberately NO
 * `uid`, NO `coupleId`, NO text field — deletion/export events are
 * special-category-adjacent, so the type signature is the guarantee (the coach
 * logCoachEvent precedent, hardened: even coupleId is dropped here). Ops can count
 * outcomes and read latency; they can never attribute an event to a person.
 */
export interface DataRightsEventLog {
  op: DataRightsOp;
  outcome: DataRightsOutcome;
  latencyMs?: number;
}

/** Projects a data-rights log line — every field a non-identifying value. */
export function logDataRightsEvent(input: {
  op: DataRightsOp;
  outcome: DataRightsOutcome;
  latencyMs?: number;
}): DataRightsEventLog {
  const event: DataRightsEventLog = { op: input.op, outcome: input.outcome };
  if (input.latencyMs !== undefined) {
    event.latencyMs = input.latencyMs;
  }
  return event;
}

// --- export projections (Decision 5) ----------------------------------------
//
// Scope: everything A authored or that is about A, nothing the partner did. The
// scrubbing is the security-critical surface, so it lives here as pure functions
// over plain records: memberUids never crosses, only lanes[A] crosses, invites
// carry no counterpart uid, and B-authored answers are never even read (the
// service queries only answers/{A}).

/** The Auth-record fields (outside Firestore) the export carries for the subject. */
export interface AuthProfile {
  displayName: string | null;
  email: string | null;
  photoURL: string | null;
}

export interface ExportProfile {
  status: string | null;
  contentLanguage: string | null;
  register: string | null;
  createdAtMs: number | null;
  notificationPrivacy?: string;
  displayName: string | null;
  email: string | null;
  photoURL: string | null;
}

export interface ExportSoloAnswer {
  dayKey: string;
  questionId: string | null;
  text: string | null;
  answeredAtMs: number | null;
}

export interface ExportStreak {
  count: number | null;
  lastMutualDate: string | null;
  graceTokens: number | null;
}

export interface ExportCoupleContext {
  coupleId: string;
  createdAtMs: number | null;
  timezone: string | null;
  streak: ExportStreak | null;
  coachMonthlyCount: number | null;
}

export interface ExportCoupleAnswer {
  dayKey: string;
  questionId: string | null;
  text: string | null;
  answeredAtMs: number | null;
  revealed: boolean;
}

export interface ExportDailyLane {
  dayKey: string | null;
  count: number | null;
}

export interface ExportSubscriptionSummary {
  entitled: boolean;
  productId: string | null;
  periodType: string | null;
  expiresAtMs: number | null;
  willRenew: boolean;
  store: string | null;
  environment: string | null;
}

export interface ExportSubscriptionLane {
  entitled: boolean;
  productId: string | null;
  periodType: string | null;
  expiresAtMs: number | null;
  willRenew: boolean;
  store: string | null;
  environment: string | null;
  entitlementIds: string[] | null;
  lastEventId: string | null;
  lastEventTimestampMs: number | null;
  updatedAtMs: number | null;
}

export interface ExportSubscription {
  summary: ExportSubscriptionSummary;
  /** ONLY lanes[A] — the partner's lane is the partner's data (Decision 5). */
  lane: ExportSubscriptionLane | null;
}

export interface ExportInvite {
  code: string;
  role: 'creator' | 'joiner';
  status: string | null;
  createdAtMs: number | null;
  expiresAtMs: number | null;
  joinedAtMs: number | null;
}

export interface ExportData {
  profile: ExportProfile;
  soloAnswers: ExportSoloAnswer[];
  coupleContext: ExportCoupleContext | null;
  coupleAnswers: ExportCoupleAnswer[];
  coachUsage: { daily: ExportDailyLane | null };
  subscription: ExportSubscription | null;
  invites: ExportInvite[];
  note: string;
}

export interface ExportEnvelope {
  formatVersion: number;
  generatedAt: string;
  uid: string;
  data: ExportData;
}

/** users/{A} client fields + the Auth record + notificationPrivacy if set. */
export function projectProfile(
  userData: Record<string, unknown>,
  auth: AuthProfile | null,
): ExportProfile {
  const profile: ExportProfile = {
    status: asStringOrNull(userData.status),
    contentLanguage: asStringOrNull(userData.contentLanguage),
    register: asStringOrNull(userData.register),
    createdAtMs: toMillis(userData.createdAt),
    displayName: auth?.displayName ?? null,
    email: auth?.email ?? null,
    photoURL: auth?.photoURL ?? null,
  };
  if (typeof userData.notificationPrivacy === 'string') {
    profile.notificationPrivacy = userData.notificationPrivacy;
  }
  return profile;
}

export function projectSoloAnswer(
  dayKey: string,
  data: Record<string, unknown>,
): ExportSoloAnswer {
  return {
    dayKey,
    questionId: asStringOrNull(data.questionId),
    text: asStringOrNull(data.text),
    answeredAtMs: toMillis(data.answeredAt),
  };
}

function projectStreak(raw: unknown): ExportStreak | null {
  if (!isRecord(raw)) {
    return null;
  }
  return {
    count: asNumberOrNull(raw.count),
    lastMutualDate: asStringOrNull(raw.lastMutualDate),
    graceTokens: asNumberOrNull(raw.graceTokens),
  };
}

/**
 * The couple context A belongs to (Decision 5): coupleId, createdAt, timezone,
 * the jointly-derived streak, and the coach MONTHLY counter — never memberUids,
 * never any appearance of B's uid. `coachUsageParent` is the coachUsage/{cid}
 * parent doc (its `monthly.count` is member-readable by design).
 */
export function projectCoupleContext(
  coupleId: string,
  coupleData: Record<string, unknown>,
  coachUsageParent: Record<string, unknown> | undefined,
): ExportCoupleContext {
  const monthly =
    coachUsageParent !== undefined && isRecord(coachUsageParent.monthly)
      ? coachUsageParent.monthly
      : undefined;
  return {
    coupleId,
    createdAtMs: toMillis(coupleData.createdAt),
    timezone: asStringOrNull(coupleData.timezone),
    streak: projectStreak(coupleData.streak),
    coachMonthlyCount: monthly !== undefined ? asNumberOrNull(monthly.count) : null,
  };
}

/** ONLY answers/{A}: A's own answer text, plus whether the day revealed. */
export function projectCoupleAnswer(
  dayKey: string,
  dayData: Record<string, unknown> | undefined,
  answerData: Record<string, unknown>,
): ExportCoupleAnswer {
  return {
    dayKey,
    questionId: asStringOrNull(answerData.questionId),
    text: asStringOrNull(answerData.text),
    answeredAtMs: toMillis(answerData.answeredAt),
    revealed: dayData !== undefined && dayData.revealedAt != null,
  };
}

export function projectDailyLane(data: Record<string, unknown>): ExportDailyLane {
  return {
    dayKey: asStringOrNull(data.dayKey),
    count: asNumberOrNull(data.count),
  };
}

/** The couple summary + ONLY lanes[A]; lanes[B] and B's uid never cross. */
export function projectSubscription(
  data: Record<string, unknown>,
  uid: string,
): ExportSubscription {
  const summary: ExportSubscriptionSummary = {
    entitled: data.entitled === true,
    productId: asStringOrNull(data.productId),
    periodType: asStringOrNull(data.periodType),
    expiresAtMs: asNumberOrNull(data.expiresAtMs),
    willRenew: data.willRenew === true,
    store: asStringOrNull(data.store),
    environment: asStringOrNull(data.environment),
  };
  const lanes = isRecord(data.lanes) ? data.lanes : {};
  const laneRaw = lanes[uid];
  let lane: ExportSubscriptionLane | null = null;
  if (isRecord(laneRaw)) {
    lane = {
      entitled: laneRaw.entitled === true,
      productId: asStringOrNull(laneRaw.productId),
      periodType: asStringOrNull(laneRaw.periodType),
      expiresAtMs: asNumberOrNull(laneRaw.expiresAtMs),
      willRenew: laneRaw.willRenew === true,
      store: asStringOrNull(laneRaw.store),
      environment: asStringOrNull(laneRaw.environment),
      entitlementIds: Array.isArray(laneRaw.entitlementIds)
        ? laneRaw.entitlementIds.filter((v): v is string => typeof v === 'string')
        : null,
      lastEventId: asStringOrNull(laneRaw.lastEventId),
      lastEventTimestampMs: asNumberOrNull(laneRaw.lastEventTimestampMs),
      updatedAtMs: asNumberOrNull(laneRaw.updatedAtMs),
    };
  }
  return { summary, lane };
}

/** An invite naming A, with the counterpart uid scrubbed (Decision 5). */
export function projectInvite(
  code: string,
  data: Record<string, unknown>,
  selfUid: string,
): ExportInvite {
  return {
    code,
    role: data.creatorUid === selfUid ? 'creator' : 'joiner',
    status: asStringOrNull(data.status),
    createdAtMs: toMillis(data.createdAt),
    expiresAtMs: toMillis(data.expiresAt),
    joinedAtMs: toMillis(data.joinedAt),
  };
}
