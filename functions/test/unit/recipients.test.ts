import { describe, expect, it } from 'vitest';

import {
  contentLanguageOf,
  fcmTokensOf,
  notificationPrivacyOf,
  resolveDiscreet,
} from '../../src/notifications/recipients';

// M3.4 (ADR-012 decision 3). Defensive readers over the untyped users/{uid} doc.
// They must never throw on shape and must default safely: discreet defaults ON in
// AR (PRD F6), unknown language falls back to the founder default 'tr', and the
// FCM token array — which nothing writes yet — reads as [] for every junk shape.

describe('resolveDiscreet (ADR-019 D6: per-user override + AR default)', () => {
  it('defaults ON for the AR locale even with no override (PRD F6)', () => {
    expect(resolveDiscreet('ar')).toBe(true);
    expect(resolveDiscreet('ar', undefined)).toBe(true);
  });

  it("turns ON for a non-AR locale when notificationPrivacy is exactly 'discreet'", () => {
    expect(resolveDiscreet('tr', 'discreet')).toBe(true);
    expect(resolveDiscreet('en', 'discreet')).toBe(true);
  });

  it('stays OFF for a non-AR locale with no override', () => {
    expect(resolveDiscreet('tr')).toBe(false);
    expect(resolveDiscreet('tr', undefined)).toBe(false);
    expect(resolveDiscreet('en', undefined)).toBe(false);
  });

  it('ignores junk override values (only the exact string counts)', () => {
    expect(resolveDiscreet('tr', 'DISCREET')).toBe(false); // exact match only
    expect(resolveDiscreet('tr', 'named')).toBe(false);
    expect(resolveDiscreet('tr', 42)).toBe(false);
    expect(resolveDiscreet('tr', {})).toBe(false);
    expect(resolveDiscreet('tr', null)).toBe(false);
    // AR + junk override still discreet (the locale default wins).
    expect(resolveDiscreet('ar', 'garbage')).toBe(true);
  });
});

describe('notificationPrivacyOf', () => {
  it('returns the field as a clean string when present', () => {
    expect(notificationPrivacyOf({ notificationPrivacy: 'discreet' })).toBe('discreet');
  });

  it('returns undefined for absent / non-string / non-object shapes', () => {
    expect(notificationPrivacyOf({})).toBeUndefined();
    expect(notificationPrivacyOf({ notificationPrivacy: 5 })).toBeUndefined();
    expect(notificationPrivacyOf({ notificationPrivacy: null })).toBeUndefined();
    expect(notificationPrivacyOf(undefined)).toBeUndefined();
    expect(notificationPrivacyOf(null)).toBeUndefined();
    expect(notificationPrivacyOf('discreet')).toBeUndefined();
  });
});

describe('fcmTokensOf', () => {
  it('returns the clean string array when well-formed', () => {
    expect(fcmTokensOf({ fcmTokens: ['a', 'b'] })).toEqual(['a', 'b']);
  });

  it('drops non-string and empty-string entries', () => {
    expect(fcmTokensOf({ fcmTokens: ['a', 1, null, '', undefined, {}, 'b'] })).toEqual(['a', 'b']);
  });

  it('returns [] for an empty array', () => {
    expect(fcmTokensOf({ fcmTokens: [] })).toEqual([]);
  });

  it('returns [] when the field is absent', () => {
    expect(fcmTokensOf({})).toEqual([]);
    expect(fcmTokensOf({ other: 'x' })).toEqual([]);
  });

  it('returns [] when the field is present but not an array', () => {
    expect(fcmTokensOf({ fcmTokens: 'token' })).toEqual([]);
    expect(fcmTokensOf({ fcmTokens: 42 })).toEqual([]);
    expect(fcmTokensOf({ fcmTokens: { 0: 'a' } })).toEqual([]);
    expect(fcmTokensOf({ fcmTokens: null })).toEqual([]);
  });

  it('returns [] for non-object userData (missing doc, primitives)', () => {
    expect(fcmTokensOf(undefined)).toEqual([]);
    expect(fcmTokensOf(null)).toEqual([]);
    expect(fcmTokensOf('nope')).toEqual([]);
    expect(fcmTokensOf(7)).toEqual([]);
  });
});

describe('contentLanguageOf', () => {
  it('returns the stored language when it is a known value', () => {
    expect(contentLanguageOf({ contentLanguage: 'tr' })).toBe('tr');
    expect(contentLanguageOf({ contentLanguage: 'ar' })).toBe('ar');
    expect(contentLanguageOf({ contentLanguage: 'en' })).toBe('en');
  });

  it('falls back to the founder default tr for unknown or malformed values', () => {
    expect(contentLanguageOf({ contentLanguage: 'de' })).toBe('tr');
    expect(contentLanguageOf({ contentLanguage: 'EN' })).toBe('tr'); // exact match only
    expect(contentLanguageOf({ contentLanguage: 5 })).toBe('tr');
    expect(contentLanguageOf({ contentLanguage: null })).toBe('tr');
  });

  it('falls back to tr when the field is absent or userData is not an object', () => {
    expect(contentLanguageOf({})).toBe('tr');
    expect(contentLanguageOf(undefined)).toBe('tr');
    expect(contentLanguageOf(null)).toBe('tr');
    expect(contentLanguageOf('tr')).toBe('tr'); // a bare string is not the doc
  });
});
