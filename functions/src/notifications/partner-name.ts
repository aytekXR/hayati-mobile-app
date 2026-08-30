// The partner display-name lookup for `partnerAnswered` push copy (ADR-065
// Decision 1, issue #253).
//
// WHERE THE NAME LIVES, AND WHY IT IS NOT IN FIRESTORE. `users/{uid}` stores no
// name, by design — `auth_repository.dart` says so at the write site and names
// this seam's sibling as the precedent: the display name is on the Firebase
// **Auth** record, and `invites/invite-preview.ts` already reads it that way for
// the zero-auth invite preview. Mirroring it into the user document would buy a
// second copy of a mutable personal datum, a new server-owned field needing a
// rules freeze in both directions, a deletion-cascade entry, an export-lane entry
// (ADR-054) and a staleness bug the Auth record does not have.
//
// ⚠️ WHAT COMES BACK IS UNTRUSTED. `displayName` is set by the user themselves
// through the Auth client SDK's `updateProfile` — the app's name-capture screen
// caps input at 50, but that is a keyboard bound, not a write bound, and the
// screen is not the only writer. Everything this module returns goes through
// `sanitizePushName` before it can reach a payload; read that file's header for
// what it is defending against.
import { getAuth } from 'firebase-admin/auth';
import { logger } from 'firebase-functions';

/** Resolves one member's display name (injectable so the Auth call is fakeable). */
export type PartnerNameLookup = (uid: string) => Promise<string | undefined>;

/**
 * Production lookup: the display name lives on the AUTH record. Rejects when the
 * record is gone or Auth is unavailable — `resolvePartnerName` is what contains
 * that, and no caller should use this directly.
 */
export const authPartnerName: PartnerNameLookup = (uid) =>
  getAuth()
    .getUser(uid)
    .then((user) => user.displayName);

/**
 * Best-effort name resolution. **NEVER throws**, and that is load-bearing rather
 * than defensive habit: `deliverPush`'s ambient `catch` returns `send-failed`, so
 * an escaping lookup error would silently convert *"we could not find out their
 * name"* into *"the notification was not sent"* — turning a cosmetic degradation
 * into a lost push.
 *
 * A deleted author, an unavailable Auth backend, and an absent `displayName`
 * (routine for Sign in with Apple's private relay) all resolve to `undefined`,
 * which routes the caller to the name-free copy that is already written, already
 * shipped and already tested.
 *
 * A THROW logs at warn — an operator investigating a name-free push must be able
 * to tell "Auth was unreachable" from "they have no name". A clean lookup that
 * simply has no name logs NOTHING: that is the ordinary case for a whole sign-in
 * method, and a warning per push for the normal state is how a log stops being
 * read (ADR-065 D1).
 */
export async function resolvePartnerName(
  lookup: PartnerNameLookup,
  uid: string,
): Promise<string | undefined> {
  try {
    return await lookup(uid);
  } catch (error) {
    logger.warn('push: partner name lookup failed, sending name-free copy', {
      uid,
      error: error instanceof Error ? error.message : String(error),
    });
    return undefined;
  }
}
