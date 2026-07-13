// The Firestore half of the ADR-023 consent lane (Decision 4). `db` is injected
// by the shell. Writes users/{uid}.consent via update() so a missing profile
// fails NATIVELY (Firestore NOT_FOUND) — the Decision 4 callable-surface rule,
// made a mechanism not an assumption. The write surface stays server-owned:
// rules freeze the field against clients (create-forbid + update-freeze), so this
// callable is the only path that can set or clear it. The server stamps its own
// CURRENT_LEGAL_VERSION and the serverTimestamp — the client sends no version.
import { FieldValue, Firestore } from 'firebase-admin/firestore';

import { CURRENT_LEGAL_VERSION } from './data-rights-core';

/** Firestore's gRPC NOT_FOUND — an update() against a non-existent doc. */
const NOT_FOUND = 5;

export type ConsentResult =
  | { kind: 'ok' }
  | { kind: 'profile-missing' };

/**
 * Grants (writes { version: CURRENT_LEGAL_VERSION, acceptedAt: serverTimestamp(),
 * ageAttested: true }) or withdraws (deletes the field) users/{uid}.consent.
 * update() on a missing doc rejects with NOT_FOUND, mapped to the typed
 * `profile-missing`; any other rejection is systemic and propagates (the shell
 * maps it to a static internal).
 */
export async function setConsent(
  db: Firestore,
  uid: string,
  withdraw: boolean,
): Promise<ConsentResult> {
  try {
    await db.collection('users').doc(uid).update({
      consent: withdraw
        ? FieldValue.delete()
        : {
            version: CURRENT_LEGAL_VERSION,
            acceptedAt: FieldValue.serverTimestamp(),
            ageAttested: true,
          },
    });
    return { kind: 'ok' };
  } catch (error) {
    if ((error as { code?: unknown }).code === NOT_FOUND) {
      return { kind: 'profile-missing' };
    }
    throw error;
  }
}
