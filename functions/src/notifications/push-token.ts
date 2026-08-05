// The onCall shells for the FCM token lifecycle (ADR-042 Decision 1):
// registerPushToken and unregisterPushToken, the only two writers of the
// server-owned `users/{uid}.fcmTokens`.
//
// The mold is `recordConsent` / `updateNotificationPrivacy` (data-rights.ts):
// factories with defaulted DI, `requireUid` → validate → a service returning
// `{kind:'ok'} | {kind:'profile-missing'}` → typed `HttpsError`, and a wrapper
// that lets a deliberate HttpsError propagate verbatim while turning any other
// escape into a static `internal` — so the callable framework's own error
// auto-logger can never fire on request-derived content. Here that matters
// literally: the request-derived content IS a device token.
import { getFirestore } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';

import { FUNCTIONS_REGION } from '../invites/create-invite';
import {
  PushTokenOp,
  PushTokenOutcome,
  logPushTokenEvent,
  validatePushTokenRequest,
} from './push-token-core';
import {
  PushTokenResult,
  registerPushToken as registerPushTokenService,
  unregisterPushToken as unregisterPushTokenService,
} from './push-token-service';

export interface PushTokenResponse {
  status: 'ok';
}

type PushTokenWrite = (db: Firestore, uid: string, token: string) => Promise<PushTokenResult>;

export interface PushTokenDeps {
  db?: () => Firestore;
  now?: () => number;
  write?: PushTokenWrite;
}

/** Guard the uid itself (the emulator passes garbage tokens through as auth). */
function requireUid(request: CallableRequest, op: string): string {
  const uid = request.auth?.uid;
  if (uid === undefined || uid.length === 0) {
    throw new HttpsError('unauthenticated', `${op} requires a signed-in caller.`);
  }
  return uid;
}

/**
 * Both callables are the same shape with a different verb and a different
 * success outcome, so they share one factory rather than two near-copies that
 * could drift apart on the error taxonomy — which is the half that matters and
 * the half nobody re-reads.
 */
function makePushTokenHandler(
  op: PushTokenOp,
  successOutcome: PushTokenOutcome,
  defaultWrite: PushTokenWrite,
  failureMessage: string,
  deps: PushTokenDeps = {},
) {
  const now = deps.now ?? Date.now;
  const resolveDb = deps.db ?? getFirestore;
  const write = deps.write ?? defaultWrite;

  return async (request: CallableRequest): Promise<PushTokenResponse> => {
    const startedAt = now();
    const emit = (outcome: PushTokenOutcome): void => {
      logger.info(op, logPushTokenEvent({ op, outcome, latencyMs: now() - startedAt }));
    };
    try {
      const uid = requireUid(request, op);

      const validation = validatePushTokenRequest(request.data);
      if (!validation.ok) {
        emit('invalid');
        // `details` carries a shape category and never the token itself — details
        // cross the wire and land in client logs.
        throw new HttpsError('invalid-argument', `${op} request is malformed.`, {
          reason: 'bad-request',
        });
      }

      const result = await write(resolveDb(), uid, validation.token);
      if (result.kind === 'profile-missing') {
        emit('profile-missing');
        throw new HttpsError('failed-precondition', 'No profile to update.', {
          reason: 'profile-missing',
        });
      }
      emit(successOutcome);
      return { status: 'ok' };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      emit('internal');
      throw new HttpsError('internal', failureMessage);
    }
  };
}

export function makeRegisterPushTokenHandler(deps: PushTokenDeps = {}) {
  return makePushTokenHandler(
    'registerPushToken',
    'registered',
    registerPushTokenService,
    'The push token could not be registered.',
    deps,
  );
}

export function makeUnregisterPushTokenHandler(deps: PushTokenDeps = {}) {
  return makePushTokenHandler(
    'unregisterPushToken',
    'removed',
    unregisterPushTokenService,
    'The push token could not be removed.',
    deps,
  );
}

// --- deployed callables (europe-west1, App Check OFF — the repo-wide posture) ---

export const registerPushToken = onCall(
  {
    region: FUNCTIONS_REGION,
    enforceAppCheck: false,
  },
  makeRegisterPushTokenHandler(),
);

export const unregisterPushToken = onCall(
  {
    region: FUNCTIONS_REGION,
    enforceAppCheck: false,
  },
  makeUnregisterPushTokenHandler(),
);
