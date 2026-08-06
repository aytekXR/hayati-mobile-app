// The Firestore half of the FCM token lifecycle (ADR-042 Decision 1). `db` is
// injected by the shell, matching notification-privacy-service / consent-service.
//
// `users/{uid}.fcmTokens` is server-owned — rules forbid a client from minting it
// at create or touching it at update — so these two functions are its only
// writers. All the array's rules live in push-token-core; this module owns only
// the Firestore mechanics, and one rule that could not live anywhere else:
//
// THE EVICTION RULE. A token addresses a DEVICE; a user does not. When B signs in
// on the phone A signed out of, FCM hands B the same registration token, and if it
// is still on A's document then A receives B's notifications on a phone A no longer
// holds. That is a privacy defect, not a cleanup task. Closing it means writing
// A's document from B's request — a cross-document write no client may ever make
// under any rule we would accept — which is the argument that decided D1 in favour
// of a callable over the documented direct write.
//
// The consequence is a design rule: REGISTRATION IS AUTHORITATIVE, sign-out
// cleanup is best-effort. `registerPushToken` repairs the world; nothing is
// designed on the assumption `unregisterPushToken` ever ran, because a killed app,
// a revoked session or a phone in a drawer all skip it.
import { Firestore } from 'firebase-admin/firestore';

import { applyTokenRegistration, applyTokenRemoval } from './push-token-core';

export type PushTokenResult = { kind: 'ok' } | { kind: 'profile-missing' };

/**
 * Registers `token` to `uid` and removes it from every OTHER user document that
 * carries it, atomically.
 *
 * One transaction, because both halves must hold together: a crash between them
 * would leave the token on two documents, which is the exact state the rule
 * exists to forbid. The `array-contains` query is a single-field predicate on a
 * top-level collection, so Firestore auto-indexes it — no `firestore.indexes.json`
 * entry is required, and none is added.
 *
 * A missing profile returns the typed `profile-missing` rather than minting a
 * document: `set(merge:true)` would create a user doc carrying nothing but
 * `fcmTokens`, an orphan that no other code path expects. Both existing callables
 * (`recordConsent`, `updateNotificationPrivacy`) make the same choice for the same
 * reason.
 */
export async function registerPushToken(
  db: Firestore,
  uid: string,
  token: string,
): Promise<PushTokenResult> {
  const users = db.collection('users');
  const selfRef = users.doc(uid);

  return db.runTransaction(async (tx): Promise<PushTokenResult> => {
    // Every read before every write — the transaction contract.
    const self = await tx.get(selfRef);
    if (!self.exists) {
      return { kind: 'profile-missing' };
    }
    const holders = await tx.get(users.where('fcmTokens', 'array-contains', token));

    tx.update(selfRef, { fcmTokens: applyTokenRegistration(self.get('fcmTokens'), token) });

    for (const holder of holders.docs) {
      if (holder.id === uid) {
        // The caller's own document is written above, with the registration
        // rules applied. Evicting it here would undo that.
        continue;
      }
      tx.update(holder.ref, { fcmTokens: applyTokenRemoval(holder.get('fcmTokens'), token) });
    }

    return { kind: 'ok' };
  });
}

/**
 * Removes `token` from `uid` and from nobody else.
 *
 * Deliberately NOT the mirror of `registerPushToken`: a token arriving on the
 * wire is not proof of ownership, so a caller must never be able to strip a token
 * from another user's document by naming it. The caller's own document is the
 * only safe blast radius, and the cross-document repair is `registerPushToken`'s
 * job precisely because that path has a device to attest for it.
 *
 * Removing a token this user never held is `ok`, not an error: sign-out cleanup
 * runs on a best-effort path where "already gone" and "just removed" are the same
 * outcome to the caller.
 */
export async function unregisterPushToken(
  db: Firestore,
  uid: string,
  token: string,
): Promise<PushTokenResult> {
  const selfRef = db.collection('users').doc(uid);

  return db.runTransaction(async (tx): Promise<PushTokenResult> => {
    const self = await tx.get(selfRef);
    if (!self.exists) {
      return { kind: 'profile-missing' };
    }
    tx.update(selfRef, { fcmTokens: applyTokenRemoval(self.get('fcmTokens'), token) });
    return { kind: 'ok' };
  });
}
