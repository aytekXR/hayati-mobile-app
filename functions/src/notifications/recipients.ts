// Recipient-field resolution for the M3.4 push layer (ADR-012 decision 3).
// Defensive readers over the untyped `users/{uid}` document the trigger/sweep
// pulls: the FCM token array, the discreet-mode default, and the notification
// content language. All three tolerate absent/malformed data — the caller
// (trigger/sweep) logs and counts skips loudly; these functions never throw on
// shape and never guess an unsafe default.

import type { PushLanguage } from './payload-policy';

/**
 * Discreet-mode decision for a recipient (PRD F6: "notification privacy defaults
 * ON in AR locale"; ADR-019 Decision 6: the per-user override). True iff the
 * per-user `notificationPrivacy` field is exactly 'discreet' (opt-in, written by
 * the updateNotificationPrivacy callable) OR the resolved content language is
 * exactly 'ar' (the locale default). The override this seam anticipated now
 * exists: v1 is opt-IN only, so it can turn discreet ON but the AR default stays
 * non-overridable. Junk `notificationPrivacy` values are ignored (the
 * defensive-reader pattern) — only the exact 'discreet' string counts. Both call
 * sites (reveal-service, at-risk) read the discreet decision from here and nowhere
 * else, so it stayed a one-function change.
 */
export function resolveDiscreet(
  contentLanguage: string | undefined,
  notificationPrivacy?: unknown,
): boolean {
  return notificationPrivacy === 'discreet' || contentLanguage === 'ar';
}

/**
 * The per-user notification-privacy override off `users/{uid}.notificationPrivacy`
 * (ADR-019 Decision 6). A clean string or undefined for absent/malformed — the
 * defensive-reader contract the call sites pass into resolveDiscreet.
 */
export function notificationPrivacyOf(userData: unknown): string | undefined {
  if (typeof userData === 'object' && userData !== null) {
    const value = (userData as Record<string, unknown>).notificationPrivacy;
    if (typeof value === 'string') {
      return value;
    }
  }
  return undefined;
}

/**
 * The recipient's FCM registration tokens from `users/{uid}.fcmTokens`, as a
 * clean string array. Defensive by contract: NOTHING writes this field yet —
 * app-side capture is a platform-channel task deferred to the on-device slice
 * (ADR-012, operator-expected item 4) — so absent, non-array, or junk shapes are
 * expected, not exceptional. Absent / non-array / contains-non-strings / empty
 * all collapse to `[]`; the CALLER treats an empty result as a skip and counts
 * it loudly in the trigger/sweep summary.
 */
export function fcmTokensOf(userData: unknown): string[] {
  if (typeof userData !== 'object' || userData === null) {
    return [];
  }
  const field = (userData as Record<string, unknown>).fcmTokens;
  if (!Array.isArray(field)) {
    return [];
  }
  // Drop non-strings and empty strings — a malformed entry must never reach
  // MessagingPort.send as a "token".
  return field.filter((token): token is string => typeof token === 'string' && token.length > 0);
}

/**
 * The recipient's notification content language from `users.contentLanguage`.
 * Unknown or absent → 'tr', the founder default (ADR-007 personal-use-first; the
 * same Europe/Istanbul precedent as DEFAULT_COUPLE_TIMEZONE — the first couple is
 * Turkish-speaking, so an unresolved language is Turkish, not English).
 */
export function contentLanguageOf(userData: unknown): PushLanguage {
  if (typeof userData === 'object' && userData !== null) {
    const lang = (userData as Record<string, unknown>).contentLanguage;
    if (lang === 'tr' || lang === 'ar' || lang === 'en') {
      return lang;
    }
  }
  return 'tr';
}
