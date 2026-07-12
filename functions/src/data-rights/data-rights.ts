// The onCall shells for the M6.2 data-rights callables (ADR-019 Decisions 2/5/6):
// deleteAccount (the hard cascade), exportData (self-serve JSON), and
// updateNotificationPrivacy (the discreet override). Factories with defaulted DI
// (the coach-proxy mold) so tests inject db/now/services. Each handler wraps its
// whole body: a deliberate HttpsError propagates verbatim (static message), any
// other escape becomes a static `internal` — never a raw rethrow — so the callable
// framework's own error auto-logger can NEVER fire on request-derived content.
// Every log line goes through logDataRightsEvent (typed fields ONLY — no text, no
// uid, no coupleId): deletion/export events are special-category-adjacent.
import { getFirestore } from 'firebase-admin/firestore';
import type { DeleteUsersResult } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';

import { FUNCTIONS_REGION } from '../invites/create-invite';
import {
  AuthProfile,
  DataRightsOutcome,
  ExportEnvelope,
  logDataRightsEvent,
  validateDeleteRequest,
  validateNotificationPrivacyRequest,
} from './data-rights-core';
import { DeletionDeps, deleteAccountCascade } from './deletion-service';
import { ExportDeps, buildExportDocument } from './export-service';
import { setNotificationPrivacy } from './notification-privacy-service';

/** The deleteAccount timeout: this owns the only unbounded multi-collection work. */
export const DELETE_ACCOUNT_TIMEOUT_SECONDS = 540;

export interface DeleteAccountResponse {
  status: 'deleted';
}
export interface UpdateNotificationPrivacyResponse {
  status: 'ok';
}

/** Guard the uid itself (the emulator passes garbage tokens through as auth). */
function requireUid(request: CallableRequest, op: string): string {
  const uid = request.auth?.uid;
  if (uid === undefined || uid.length === 0) {
    throw new HttpsError('unauthenticated', `${op} requires a signed-in caller.`);
  }
  return uid;
}

// --- deleteAccount ----------------------------------------------------------

export interface DeleteAccountDeps {
  db?: () => Firestore;
  now?: () => number;
  /** Injectable cascade (default the real one) so the shell's mapping is testable. */
  cascade?: (db: Firestore, uid: string, deps: DeletionDeps) => Promise<{ status: 'deleted' }>;
  /** Forwarded to the cascade's auth-delete seam. */
  deleteAuthUsers?: (uids: string[]) => Promise<DeleteUsersResult>;
}

export function makeDeleteAccountHandler(deps: DeleteAccountDeps = {}) {
  const now = deps.now ?? Date.now;
  const resolveDb = deps.db ?? getFirestore;
  const cascade = deps.cascade ?? deleteAccountCascade;

  return async (request: CallableRequest): Promise<DeleteAccountResponse> => {
    const startedAt = now();
    const emit = (outcome: DataRightsOutcome): void => {
      logger.info(
        'deleteAccount',
        logDataRightsEvent({ op: 'deleteAccount', outcome, latencyMs: now() - startedAt }),
      );
    };
    try {
      const uid = requireUid(request, 'deleteAccount');

      const validation = validateDeleteRequest(request.data);
      if (!validation.ok) {
        emit('invalid');
        throw new HttpsError(
          'invalid-argument',
          'deleteAccount requires an explicit confirmation.',
          { reason: 'bad-confirm' },
        );
      }

      await cascade(resolveDb(), uid, { deleteAuthUsers: deps.deleteAuthUsers });
      emit('deleted');
      return { status: 'deleted' };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      emit('internal');
      throw new HttpsError('internal', 'Account deletion could not be completed.');
    }
  };
}

// --- exportData -------------------------------------------------------------

export interface ExportDataDeps {
  db?: () => Firestore;
  now?: () => number;
  authLookup?: (uid: string) => Promise<AuthProfile | null>;
  build?: (db: Firestore, uid: string, deps: ExportDeps) => Promise<
    { kind: 'ok'; document: ExportEnvelope } | { kind: 'profile-missing' }
  >;
}

export function makeExportDataHandler(deps: ExportDataDeps = {}) {
  const now = deps.now ?? Date.now;
  const resolveDb = deps.db ?? getFirestore;
  const build = deps.build ?? buildExportDocument;

  return async (request: CallableRequest): Promise<ExportEnvelope> => {
    const startedAt = now();
    const emit = (outcome: DataRightsOutcome): void => {
      logger.info(
        'exportData',
        logDataRightsEvent({ op: 'exportData', outcome, latencyMs: now() - startedAt }),
      );
    };
    try {
      const uid = requireUid(request, 'exportData');

      const result = await build(resolveDb(), uid, { now, authLookup: deps.authLookup });
      if (result.kind === 'profile-missing') {
        emit('profile-missing');
        throw new HttpsError('failed-precondition', 'No profile to export.', {
          reason: 'profile-missing',
        });
      }
      emit('exported');
      return result.document;
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      emit('internal');
      throw new HttpsError('internal', 'The export could not be produced.');
    }
  };
}

// --- updateNotificationPrivacy ----------------------------------------------

export interface UpdateNotificationPrivacyDeps {
  db?: () => Firestore;
  now?: () => number;
  setPrivacy?: (
    db: Firestore,
    uid: string,
    discreet: boolean,
  ) => Promise<{ kind: 'ok' } | { kind: 'profile-missing' }>;
}

export function makeUpdateNotificationPrivacyHandler(
  deps: UpdateNotificationPrivacyDeps = {},
) {
  const now = deps.now ?? Date.now;
  const resolveDb = deps.db ?? getFirestore;
  const setPrivacy = deps.setPrivacy ?? setNotificationPrivacy;

  return async (request: CallableRequest): Promise<UpdateNotificationPrivacyResponse> => {
    const startedAt = now();
    const emit = (outcome: DataRightsOutcome): void => {
      logger.info(
        'updateNotificationPrivacy',
        logDataRightsEvent({
          op: 'updateNotificationPrivacy',
          outcome,
          latencyMs: now() - startedAt,
        }),
      );
    };
    try {
      const uid = requireUid(request, 'updateNotificationPrivacy');

      const validation = validateNotificationPrivacyRequest(request.data);
      if (!validation.ok) {
        emit('invalid');
        throw new HttpsError('invalid-argument', 'updateNotificationPrivacy request is malformed.', {
          reason: 'bad-request',
        });
      }

      const result = await setPrivacy(resolveDb(), uid, validation.discreet);
      if (result.kind === 'profile-missing') {
        emit('profile-missing');
        throw new HttpsError('failed-precondition', 'No profile to update.', {
          reason: 'profile-missing',
        });
      }
      emit('updated');
      return { status: 'ok' };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      emit('internal');
      throw new HttpsError('internal', 'The setting could not be updated.');
    }
  };
}

// --- deployed callables (europe-west1, App Check OFF — the repo-wide posture) ---

export const deleteAccount = onCall(
  {
    region: FUNCTIONS_REGION,
    enforceAppCheck: false,
    timeoutSeconds: DELETE_ACCOUNT_TIMEOUT_SECONDS,
  },
  makeDeleteAccountHandler(),
);

export const exportData = onCall(
  {
    region: FUNCTIONS_REGION,
    enforceAppCheck: false,
  },
  makeExportDataHandler(),
);

export const updateNotificationPrivacy = onCall(
  {
    region: FUNCTIONS_REGION,
    enforceAppCheck: false,
  },
  makeUpdateNotificationPrivacyHandler(),
);
