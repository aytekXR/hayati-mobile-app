import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import {
  CallableRequest,
  HttpsError,
  onCall,
} from 'firebase-functions/v2/https';

import {
  InviteCodeSpaceExhaustedError,
  IssuedInvite,
  issueInvite,
} from './invite-service';

/**
 * All Hayati callables live in europe-west1: closest single region to both
 * Istanbul and Riyadh and consistent with the eur3 Firestore placement
 * (architecture.md §1). The M2.2 client must construct its callable instance
 * with this region.
 */
export const FUNCTIONS_REGION = 'europe-west1';

/**
 * Handler factory: `issue` is injectable so the error paths are unit-testable
 * without rigging Firestore itself. Production wiring passes nothing.
 */
export function makeCreateInviteHandler(issue: typeof issueInvite = issueInvite) {
  return async (request: CallableRequest): Promise<IssuedInvite> => {
    // Guard the uid itself, not just auth presence: the functions EMULATOR
    // skips real token verification (FIREBASE_DEBUG_MODE), so a garbage
    // bearer token arrives here as auth with uid undefined — and production
    // defense-in-depth costs nothing.
    const uid = request.auth?.uid;
    if (uid === undefined || uid.length === 0) {
      throw new HttpsError(
        'unauthenticated',
        'createInvite requires a signed-in caller.',
      );
    }
    // App Check posture (M1.3, architecture.md §2): the client plumbs a token
    // but enforcement stays OFF until on-device attestation is verified.
    // Log presence so attestation coverage is observable before flipping it on.
    logger.info('createInvite', {
      uid,
      appCheckPresent: request.app !== undefined,
    });
    try {
      return await issue(getFirestore(), uid);
    } catch (error) {
      if (error instanceof InviteCodeSpaceExhaustedError) {
        throw new HttpsError(
          'resource-exhausted',
          'No invite code could be allocated; please try again.',
        );
      }
      logger.error('createInvite failed', error);
      throw new HttpsError('internal', 'Failed to issue an invite.');
    }
  };
}

export const createInvite = onCall(
  {
    region: FUNCTIONS_REGION,
    // Deliberately explicit even though false is the default: enforcement is
    // a founder-gated decision (FOUNDER-ACTIONS: on-device App Attest first).
    enforceAppCheck: false,
  },
  makeCreateInviteHandler(),
);
