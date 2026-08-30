import { describe, expect, it, vi } from 'vitest';

import { resolvePartnerName } from '../../src/notifications/partner-name';

// ADR-065 Decision 1, issue #253.
//
// One contract, and it is load-bearing rather than defensive habit:
// `resolvePartnerName` NEVER throws. `deliverPush` wraps its whole body in a
// `catch` that returns `send-failed`, so a lookup error that escaped would
// silently convert "we could not find out their name" into "the notification was
// not sent" — a cosmetic degradation turned into a lost push. The Auth record
// can be gone (a partner deleting their account mid-flight), Auth can be
// unreachable, and `displayName` is simply absent for most Sign in with Apple
// accounts, so every one of these is an ordinary Tuesday, not an incident.
//
// The production lookup itself (`authPartnerName`) is runtime wiring over
// `getAuth()`; it is covered by the emulator suite, which omits the injection so
// the real call runs — the `invite-preview.test.ts` precedent for the same shape.
describe('resolvePartnerName never lets a name failure become a push failure', () => {
  it('returns the name when the lookup resolves one', async () => {
    await expect(resolvePartnerName(async () => 'Aylin', 'uid-a')).resolves.toBe('Aylin');
  });

  it('returns undefined when the record has no displayName', async () => {
    // The routine case, not an error: Sign in with Apple's private relay
    // routinely yields an account with no name at all.
    await expect(resolvePartnerName(async () => undefined, 'uid-a')).resolves.toBeUndefined();
  });

  it('swallows a rejection and degrades to no name', async () => {
    const warn = vi.spyOn(await import('firebase-functions').then((m) => m.logger), 'warn');
    warn.mockImplementation(() => undefined);
    const lookup = vi.fn().mockRejectedValue(new Error('there is no user record'));

    await expect(resolvePartnerName(lookup, 'uid-gone')).resolves.toBeUndefined();

    expect(lookup).toHaveBeenCalledWith('uid-gone');
    // A THROW logs, because an operator investigating a name-free push must be
    // able to tell "Auth was unreachable" from "they have no name" (ADR-065 D1).
    expect(warn).toHaveBeenCalledTimes(1);
    warn.mockRestore();
  });

  it('swallows a non-Error rejection too', async () => {
    const warn = vi.spyOn(await import('firebase-functions').then((m) => m.logger), 'warn');
    warn.mockImplementation(() => undefined);
    await expect(resolvePartnerName(() => Promise.reject('nope'), 'uid-a')).resolves.toBeUndefined();
    expect(warn).toHaveBeenCalledTimes(1);
    warn.mockRestore();
  });

  it('does NOT log when the lookup cleanly has no name', async () => {
    // A warning per push for the normal state is how a log stops being read.
    const warn = vi.spyOn(await import('firebase-functions').then((m) => m.logger), 'warn');
    warn.mockImplementation(() => undefined);
    await resolvePartnerName(async () => undefined, 'uid-a');
    expect(warn).not.toHaveBeenCalled();
    warn.mockRestore();
  });
});
