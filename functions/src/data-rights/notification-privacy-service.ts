// The Firestore half of the M6.2 discreet-notification override (ADR-019
// Decision 6). `db` is injected by the shell. Writes users/{uid}.notificationPrivacy
// via update() so a missing profile fails NATIVELY (Firestore NOT_FOUND) — the
// Decision 2 callable-surface rule, made a mechanism not an assumption. The write
// surface stays server-owned: rules freeze the field against clients, so this
// callable is the only path that can set or clear it.
import { FieldValue, Firestore } from 'firebase-admin/firestore';

/** Firestore's gRPC NOT_FOUND — an update() against a non-existent doc. */
const NOT_FOUND = 5;

export type NotificationPrivacyResult =
  | { kind: 'ok' }
  | { kind: 'profile-missing' };

/**
 * Sets users/{uid}.notificationPrivacy = 'discreet' (opt-in) or deletes the field
 * (back to the locale default). update() on a missing doc rejects with NOT_FOUND,
 * mapped to the typed `profile-missing`; any other rejection is systemic and
 * propagates (the shell maps it to a static internal).
 */
export async function setNotificationPrivacy(
  db: Firestore,
  uid: string,
  discreet: boolean,
): Promise<NotificationPrivacyResult> {
  try {
    await db.collection('users').doc(uid).update({
      notificationPrivacy: discreet ? 'discreet' : FieldValue.delete(),
    });
    return { kind: 'ok' };
  } catch (error) {
    if ((error as { code?: unknown }).code === NOT_FOUND) {
      return { kind: 'profile-missing' };
    }
    throw error;
  }
}
