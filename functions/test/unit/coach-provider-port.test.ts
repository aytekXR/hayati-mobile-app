// Unit tests for the coach provider seam (ADR-016 Decision 5): FixtureCoachProvider
// replay + ordered call log + throwing scenario; UnconfiguredCoachProvider's
// fail-closed classification-only error; and ProviderUnavailableError's STATIC,
// enum-derived message (no free text can ever reach it). No live calls.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import {
  CoachFixtureEntry,
  CoachProvider,
  CoachProviderRequest,
  FixtureCoachProvider,
  PROVIDER_UNAVAILABLE_CLASSIFICATIONS,
  PROVIDER_UNAVAILABLE_MESSAGES,
  ProviderUnavailableError,
  UnconfiguredCoachProvider,
} from '../../src/coach/provider-port';

const FIXTURE_PATH = fileURLToPath(new URL('../fixtures/coach-provider-fixtures.json', import.meta.url));

function req(overrides: Partial<CoachProviderRequest> = {}): CoachProviderRequest {
  return {
    personaId: 'coach',
    language: 'tr',
    register: 'tr-playful',
    messages: [{ role: 'user', text: 'merhaba' }],
    ...overrides,
  };
}

describe('FixtureCoachProvider — recorded replay + call log', () => {
  it('replays entries in order and records the ordered call log', async () => {
    const provider = new FixtureCoachProvider([{ text: 'first' }, { text: 'second' }]);
    expect(provider.calls).toHaveLength(0); // "zero calls" baseline the safety tests key on

    const a = await provider.generateReply(req({ personaId: 'coach' }));
    const b = await provider.generateReply(req({ personaId: 'dateGenie' }));

    expect(a.text).toBe('first');
    expect(b.text).toBe('second');
    expect(provider.calls.map((c) => c.personaId)).toEqual(['coach', 'dateGenie']);
  });

  it('reuses the last entry past the end (single-entry provider answers every call)', async () => {
    const provider = new FixtureCoachProvider([{ text: 'only' }]);
    expect((await provider.generateReply(req())).text).toBe('only');
    expect((await provider.generateReply(req())).text).toBe('only');
    expect(provider.calls).toHaveLength(2);
  });

  it('a {throws} entry raises the classified ProviderUnavailableError (and logs the call)', async () => {
    const provider = new FixtureCoachProvider([{ throws: 'upstream-error' }]);
    await expect(provider.generateReply(req())).rejects.toBeInstanceOf(ProviderUnavailableError);
    await expect(provider.generateReply(req())).rejects.toMatchObject({ classification: 'upstream-error' });
    expect(provider.calls).toHaveLength(2); // the request is logged BEFORE the throw
  });

  it('refuses to construct with zero entries', () => {
    expect(() => new FixtureCoachProvider([])).toThrow();
  });
});

describe('UnconfiguredCoachProvider — fail-closed production default', () => {
  it('always throws ProviderUnavailableError("unconfigured")', async () => {
    const provider: CoachProvider = new UnconfiguredCoachProvider();
    await expect(provider.generateReply(req())).rejects.toBeInstanceOf(ProviderUnavailableError);
    await expect(provider.generateReply(req())).rejects.toMatchObject({ classification: 'unconfigured' });
  });
});

describe('ProviderUnavailableError — classification-only, static message', () => {
  it.each(PROVIDER_UNAVAILABLE_CLASSIFICATIONS)('message for %s matches the static enum table', (classification) => {
    const error = new ProviderUnavailableError(classification);
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('ProviderUnavailableError');
    expect(error.classification).toBe(classification);
    expect(error.message).toBe(PROVIDER_UNAVAILABLE_MESSAGES[classification]);
  });

  it('every message is one of the four static strings — nothing free-text can appear', () => {
    const allowed = new Set(Object.values(PROVIDER_UNAVAILABLE_MESSAGES));
    for (const classification of PROVIDER_UNAVAILABLE_CLASSIFICATIONS) {
      expect(allowed.has(new ProviderUnavailableError(classification).message)).toBe(true);
    }
    // The message never carries upstream/request text: it is a function of the
    // enum ONLY (the constructor accepts nothing else).
    expect(new ProviderUnavailableError('upstream-error').message).not.toMatch(/\d{3}/); // no "400"/status codes
  });
});

describe('recorded fixtures file — shape + provider construction', () => {
  const fixtures = JSON.parse(readFileSync(FIXTURE_PATH, 'utf8')) as {
    policy: string;
    scenarios: Record<string, CoachFixtureEntry>;
  };

  it('is policy-headed with a content note and carries the pinned scenarios', () => {
    expect(fixtures.policy).toMatch(/CONTENT NOTE/i);
    expect(Object.keys(fixtures.scenarios)).toEqual(
      expect.arrayContaining(['coach-normal', 'dateGenie-normal', 'giftGenie-normal', 'crisis-in-reply', 'upstream-failure']),
    );
  });

  it('constructs a working provider from a recorded normal scenario', async () => {
    const provider = new FixtureCoachProvider([fixtures.scenarios['coach-normal']]);
    const reply = await provider.generateReply(req());
    expect(reply.text.length).toBeGreaterThan(0);
  });

  it('the throwing scenario drives the unavailable path', async () => {
    const provider = new FixtureCoachProvider([fixtures.scenarios['upstream-failure']]);
    await expect(provider.generateReply(req())).rejects.toMatchObject({ classification: 'upstream-error' });
  });
});
