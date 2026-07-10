// Pure unit tests for the join Function's non-Firestore surface — no emulator
// required: the IANA timezone validator (runtime allow-list) and the typed
// domain-error taxonomy the handler maps to HttpsError reasons. The
// transactional join itself is exercised against the emulator in
// test/emulator/join-service.test.ts.
import { describe, expect, it } from 'vitest';

import {
  AlreadyPairedError,
  ConsumedInviteError,
  DEFAULT_COUPLE_TIMEZONE,
  ExpiredInviteError,
  JoinInviteError,
  ProfileMissingError,
  SelfJoinError,
  UnknownInviteError,
  resolveCoupleTimezone,
} from '../../src/invites/join-service';

describe('resolveCoupleTimezone', () => {
  it('keeps a valid IANA timezone the device supplied', () => {
    expect(resolveCoupleTimezone('Asia/Riyadh')).toBe('Asia/Riyadh');
    expect(resolveCoupleTimezone('Europe/Istanbul')).toBe('Europe/Istanbul');
    expect(resolveCoupleTimezone('America/New_York')).toBe('America/New_York');
  });

  it('falls back to the default for an unrecognised zone', () => {
    expect(resolveCoupleTimezone('Mars/Olympus_Mons')).toBe(
      DEFAULT_COUPLE_TIMEZONE,
    );
    expect(resolveCoupleTimezone('Not/AZone')).toBe(DEFAULT_COUPLE_TIMEZONE);
    // A non-empty-but-junk string is not a real zone either.
    expect(resolveCoupleTimezone('UTC+3')).toBe(DEFAULT_COUPLE_TIMEZONE);
  });

  it('falls back to the default when absent or empty', () => {
    expect(resolveCoupleTimezone()).toBe(DEFAULT_COUPLE_TIMEZONE);
    expect(resolveCoupleTimezone(undefined)).toBe(DEFAULT_COUPLE_TIMEZONE);
    expect(resolveCoupleTimezone('')).toBe(DEFAULT_COUPLE_TIMEZONE);
  });

  it('the default is Istanbul (TR soft-launch / founder home zone)', () => {
    expect(DEFAULT_COUPLE_TIMEZONE).toBe('Europe/Istanbul');
  });
});

describe('JoinInviteError taxonomy', () => {
  // The handler maps by `reason` alone, so the reason on each class IS the wire
  // contract — this table locks it (a rename would turn CI red here, not in an
  // integration test).
  const cases: Array<[JoinInviteError, string]> = [
    [new UnknownInviteError(), 'unknown'],
    [new ExpiredInviteError(), 'expired'],
    [new ConsumedInviteError(), 'consumed'],
    [new SelfJoinError(), 'self-join'],
    [new AlreadyPairedError(), 'already-paired'],
    [new ProfileMissingError(), 'profile-missing'],
  ];

  it.each(cases)('%o carries its frozen reason', (error, reason) => {
    expect(error).toBeInstanceOf(JoinInviteError);
    expect(error).toBeInstanceOf(Error);
    expect(error.reason).toBe(reason);
    // A non-empty, client-safe message (surfaced as the HttpsError message).
    expect(error.message.length).toBeGreaterThan(0);
  });

  it('every reason is distinct', () => {
    const reasons = cases.map(([error]) => error.reason);
    expect(new Set(reasons).size).toBe(reasons.length);
  });
});
