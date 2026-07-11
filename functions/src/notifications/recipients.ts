// Recipient-field resolution for the M3.4 push layer (ADR-012 decision 3).
// Defensive readers over the untyped `users/{uid}` document the trigger/sweep
// pulls: the FCM token array, the discreet-mode default, and the notification
// content language. All three tolerate absent/malformed data — the caller
// (trigger/sweep) logs and counts skips loudly; these functions never throw on
// shape and never guess an unsafe default.

import type { PushLanguage } from './payload-policy';

/**
 * Discreet-mode default for a recipient (PRD F6: "notification privacy defaults
 * ON in AR locale"). True iff the resolved content language is exactly 'ar',
 * false otherwise. A future per-user notification-privacy SETTING will thread
 * through this same resolver seam (the settings value overriding the locale
 * default), so all callers read the discreet decision from here and nowhere
 * else — keeping that override a one-function change.
 */
export function resolveDiscreet(contentLanguage: string | undefined): boolean {
  return contentLanguage === 'ar';
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
