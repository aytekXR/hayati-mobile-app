import { describe, expect, it } from 'vitest';

import {
  MAX_FCM_TOKENS_PER_USER,
  MAX_FCM_TOKEN_LENGTH,
  applyTokenRegistration,
  applyTokenRemoval,
  logPushTokenEvent,
  sanitizeTokens,
  validatePushTokenRequest,
} from '../../src/notifications/push-token-core';

// The pure decision core for ADR-042 Decision 1: the request shape, the stored
// array's discipline (filter empties, dedupe, cap, drop element 0), and the
// PII-free log projection. Every rule the callable enforces is decided here, so
// it is provable without Firestore, without FCM and without a device.

describe('validatePushTokenRequest', () => {
  it('accepts a plausible FCM registration token', () => {
    expect(validatePushTokenRequest({ token: 'abc123' })).toEqual({
      ok: true,
      token: 'abc123',
    });
  });

  it('rejects a non-object body', () => {
    expect(validatePushTokenRequest(null)).toEqual({ ok: false, reason: 'not-object' });
    expect(validatePushTokenRequest('abc')).toEqual({ ok: false, reason: 'not-object' });
    expect(validatePushTokenRequest(undefined)).toEqual({ ok: false, reason: 'not-object' });
  });

  it('rejects a missing / non-string / empty token', () => {
    expect(validatePushTokenRequest({})).toEqual({ ok: false, reason: 'bad-token' });
    expect(validatePushTokenRequest({ token: 42 })).toEqual({ ok: false, reason: 'bad-token' });
    expect(validatePushTokenRequest({ token: '' })).toEqual({ ok: false, reason: 'bad-token' });
  });

  // A token is opaque, so the only honest bound is a generous length ceiling —
  // it exists to stop a client posting a megabyte into a user document, not to
  // second-guess Apple's or Google's token format.
  it('rejects a token longer than the ceiling, and accepts one exactly at it', () => {
    expect(validatePushTokenRequest({ token: 'x'.repeat(MAX_FCM_TOKEN_LENGTH) })).toEqual({
      ok: true,
      token: 'x'.repeat(MAX_FCM_TOKEN_LENGTH),
    });
    expect(validatePushTokenRequest({ token: 'x'.repeat(MAX_FCM_TOKEN_LENGTH + 1) })).toEqual({
      ok: false,
      reason: 'bad-token',
    });
  });

  it('the ceiling is generous against real FCM tokens (~163 chars)', () => {
    expect(MAX_FCM_TOKEN_LENGTH).toBeGreaterThan(1000);
  });

  // Whitespace-only is empty wearing a disguise: it would store a "token" that
  // can never receive a push and would occupy a cap slot forever.
  it('rejects a whitespace-only token and trims the stored value', () => {
    expect(validatePushTokenRequest({ token: '   ' })).toEqual({ ok: false, reason: 'bad-token' });
    expect(validatePushTokenRequest({ token: '  abc  ' })).toEqual({ ok: true, token: 'abc' });
  });
});

describe('sanitizeTokens', () => {
  it('collapses absent / non-array / junk shapes to an empty array', () => {
    expect(sanitizeTokens(undefined)).toEqual([]);
    expect(sanitizeTokens(null)).toEqual([]);
    expect(sanitizeTokens('abc')).toEqual([]);
    expect(sanitizeTokens({})).toEqual([]);
  });

  it('drops non-strings and empties, and preserves order', () => {
    expect(sanitizeTokens(['a', '', 'b', 42, null, 'c'])).toEqual(['a', 'b', 'c']);
  });

  it('de-duplicates, keeping the LAST occurrence so position tracks recency', () => {
    expect(sanitizeTokens(['a', 'b', 'a'])).toEqual(['b', 'a']);
  });

  // sanitizeTokens is the same contract recipients.fcmTokensOf reads with. If
  // they ever disagree, the writer stores something the sender silently drops.
  it('never returns an entry the sender would reject', () => {
    for (const token of sanitizeTokens(['a', '', 42, 'b'] as unknown[])) {
      expect(typeof token).toBe('string');
      expect(token.length).toBeGreaterThan(0);
    }
  });
});

describe('applyTokenRegistration', () => {
  it('appends a new token to an empty document', () => {
    expect(applyTokenRegistration(undefined, 'a')).toEqual(['a']);
  });

  it('appends a new token after the existing ones', () => {
    expect(applyTokenRegistration(['a', 'b'], 'c')).toEqual(['a', 'b', 'c']);
  });

  // Re-registering must not grow the array: the app registers on every launch,
  // so without this a single device would consume the whole cap in five days.
  it('is idempotent — re-registering the same token does not grow the array', () => {
    expect(applyTokenRegistration(['a'], 'a')).toEqual(['a']);
    expect(applyTokenRegistration(['a', 'b'], 'b')).toEqual(['a', 'b']);
  });

  // This is what makes the cap behave like least-recently-registered rather than
  // first-ever-seen: a device that still launches keeps moving to the back and
  // never gets dropped; a device that went in a drawer drifts to element 0.
  it('moves a re-registered token to the END, so position tracks recency', () => {
    expect(applyTokenRegistration(['a', 'b', 'c'], 'a')).toEqual(['b', 'c', 'a']);
  });

  it('cleans junk out of the stored array on the way past', () => {
    expect(applyTokenRegistration(['a', '', 42, 'b'] as unknown[], 'c')).toEqual(['a', 'b', 'c']);
  });

  describe('the cap', () => {
    const full = Array.from({ length: MAX_FCM_TOKENS_PER_USER }, (_, i) => `t${i}`);

    it('holds the cap exactly, without dropping anything', () => {
      expect(applyTokenRegistration(full.slice(0, -1), 'last')).toHaveLength(
        MAX_FCM_TOKENS_PER_USER,
      );
    });

    it('drops ELEMENT 0 when a token past the cap arrives (ADR-042 D1)', () => {
      const result = applyTokenRegistration(full, 'newest');
      expect(result).toHaveLength(MAX_FCM_TOKENS_PER_USER);
      expect(result[0]).toBe('t1');
      expect(result).not.toContain('t0');
      expect(result[result.length - 1]).toBe('newest');
    });

    it('bounds an over-full array that somehow got stored, not just the increment', () => {
      const overfull = Array.from({ length: MAX_FCM_TOKENS_PER_USER + 7 }, (_, i) => `t${i}`);
      expect(applyTokenRegistration(overfull, 'newest')).toHaveLength(MAX_FCM_TOKENS_PER_USER);
    });

    it('never drops the token being registered, even at the cap', () => {
      expect(applyTokenRegistration(full, 'newest')).toContain('newest');
    });

    it('the cap is 5 — a phone, a tablet, and room for replacements', () => {
      expect(MAX_FCM_TOKENS_PER_USER).toBe(5);
    });
  });
});

describe('applyTokenRemoval', () => {
  it('removes the token and leaves the rest in order', () => {
    expect(applyTokenRemoval(['a', 'b', 'c'], 'b')).toEqual(['a', 'c']);
  });

  it('is a no-op for a token that is not there', () => {
    expect(applyTokenRemoval(['a', 'b'], 'zzz')).toEqual(['a', 'b']);
  });

  it('collapses an absent / junk field to an empty array', () => {
    expect(applyTokenRemoval(undefined, 'a')).toEqual([]);
    expect(applyTokenRemoval(['a', 42, ''] as unknown[], 'a')).toEqual([]);
  });

  it('removes EVERY copy, so a duplicate cannot survive a sign-out', () => {
    expect(applyTokenRemoval(['a', 'b', 'a'], 'a')).toEqual(['b']);
  });
});

// ADR-042 D1: the eviction rule is the privacy property. If A signs out on a
// phone and B signs in, B's registration must remove that token from A — or A
// keeps receiving pushes meant for B, on a phone A no longer holds.
describe('the eviction invariant, stated as a property', () => {
  it('a registered token cannot remain on any other document', () => {
    const previousOwner = applyTokenRemoval(['shared', 'a-only'], 'shared');
    const newOwner = applyTokenRegistration(['b-only'], 'shared');

    expect(previousOwner).not.toContain('shared');
    expect(previousOwner).toEqual(['a-only']);
    expect(newOwner).toContain('shared');
  });
});

describe('logPushTokenEvent', () => {
  it('carries the op, outcome and latency', () => {
    expect(logPushTokenEvent({ op: 'registerPushToken', outcome: 'registered', latencyMs: 12 })).toEqual(
      { op: 'registerPushToken', outcome: 'registered', latencyMs: 12 },
    );
  });

  // The token IS the identifier here: it addresses one physical device and is a
  // credential for delivering to it. A log line carrying one would defeat the
  // whole point of making the field server-owned.
  it('carries NO token, NO uid, and no other identifier', () => {
    const line = logPushTokenEvent({
      op: 'registerPushToken',
      outcome: 'registered',
      latencyMs: 1,
    });
    expect(Object.keys(line).sort()).toEqual(['latencyMs', 'op', 'outcome']);
    expect(JSON.stringify(line)).not.toContain('token-');
  });

  it('omits latency when it was not measured', () => {
    expect(logPushTokenEvent({ op: 'unregisterPushToken', outcome: 'removed' })).toEqual({
      op: 'unregisterPushToken',
      outcome: 'removed',
    });
  });
});
