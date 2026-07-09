import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import {
  CallableRequest,
  HttpsError,
  onCall,
} from 'firebase-functions/v2/https';

import { FUNCTIONS_REGION } from './create-invite';
import {
  JoinInviteError,
  JoinResult,
  joinInvite as joinInviteService,
} from './join-service';

/**
 * Handler factory mirroring `makeCreateInviteHandler`: `join` is injectable so
 * the auth guard and the domain-error → HttpsError mapping are unit-testable
 * without rigging Firestore. Production wiring passes nothing.
 */
export function makeJoinInviteHandler(
  join: typeof joinInviteService = joinInviteService,
) {
  return async (request: CallableRequest): Promise<JoinResult> => {
    // Guard the uid itself, not just auth presence: the functions EMULATOR
    // skips real token verification (FIREBASE_DEBUG_MODE), so a garbage bearer
    // token arrives here as auth with uid undefined — and it is free
    // defence-in-depth in production (identical posture to createInvite).
    const uid = request.auth?.uid;
    if (uid === undefined || uid.length === 0) {
      throw new HttpsError(
        'unauthenticated',
        'joinInvite requires a signed-in caller.',
      );
    }

    // Wire validation (FROZEN M2.3 contract): `code` MUST be a string. A
    // non-string is a malformed request, distinct from a well-formed request
    // for a code that turns out not to exist ('not-found'/'unknown').
    const data = request.data as { code?: unknown; timezone?: unknown } | null;
    const code = data?.code;
    if (typeof code !== 'string') {
      throw new HttpsError(
        'invalid-argument',
        'joinInvite requires a string invite code.',
      );
    }
    // Optional IANA timezone; a non-string is ignored (the service falls back
    // to DEFAULT_COUPLE_TIMEZONE) rather than rejecting the whole join.
    const timezone = typeof data?.timezone === 'string' ? data.timezone : undefined;

    // App Check posture (M1.3): token plumbed, enforcement OFF — log presence so
    // attestation coverage is observable. Log a 3-char PREFIX only: pairing the
    // full code with a join outcome would turn the logs into a code oracle.
    logger.info('joinInvite', {
      uid,
      appCheckPresent: request.app !== undefined,
      codePrefix: code.slice(0, 3),
    });

    try {
      return await join(getFirestore(), uid, code, timezone);
    } catch (error) {
      if (error instanceof JoinInviteError) {
        // 'unknown' is the only not-found; every other reason is a
        // failed-precondition. The reason travels verbatim in details.
        throw new HttpsError(
          error.reason === 'unknown' ? 'not-found' : 'failed-precondition',
          error.message,
          { reason: error.reason },
        );
      }
      logger.error('joinInvite failed', error);
      throw new HttpsError('internal', 'Failed to join the invite.');
    }
  };
}

export const joinInvite = onCall(
  {
    region: FUNCTIONS_REGION,
    // Deliberately explicit even though false is the default: enforcement is a
    // founder-gated decision (FOUNDER-ACTIONS: on-device App Attest first),
    // identical to createInvite's M2.1 posture.
    enforceAppCheck: false,
  },
  makeJoinInviteHandler(),
);
