// Unit tests for the M5.3 live adapter (anthropic-provider.ts). The two
// safety-bearing pure helpers are exercised directly — the SDK network call itself
// is integration territory, out of unit scope. The load-bearing assertion is the
// ADR-016 D5 invariant: no upstream text can reach a log through the mapped error.
import Anthropic from '@anthropic-ai/sdk';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  AnthropicCoachProvider,
  classifyUpstream,
  extractReplyText,
} from '../../src/coach/anthropic-provider';
import { CoachProviderRequest, ProviderUnavailableError } from '../../src/coach/provider-port';

const SAMPLE_REQUEST: CoachProviderRequest = {
  personaId: 'coach',
  language: 'tr',
  register: 'tr-playful',
  messages: [{ role: 'user', text: 'merhaba' }],
};

/** Run a thrower and return the ProviderUnavailableError classification, or fail. */
function classificationOfThrow(fn: () => unknown): string {
  try {
    fn();
  } catch (error) {
    if (error instanceof ProviderUnavailableError) {
      return error.classification;
    }
    throw error;
  }
  throw new Error('expected a ProviderUnavailableError throw');
}

describe('classifyUpstream', () => {
  it('maps a connection timeout to `timeout`', () => {
    expect(classifyUpstream(new Anthropic.APIConnectionTimeoutError())).toBe('timeout');
  });

  it('maps any other Anthropic API/connection error to `upstream-error`', () => {
    expect(classifyUpstream(new Anthropic.APIConnectionError({ message: 'net' }))).toBe(
      'upstream-error',
    );
  });

  it('maps an unrecognized error to `unknown`', () => {
    expect(classifyUpstream(new Error('boom'))).toBe('unknown');
  });

  // The port's load-bearing safety invariant (ADR-016 D5). Reviewed S042: the
  // original single case used a PLAIN `Error`, which classifies as `unknown` — the
  // one branch that provably cannot carry an SDK response body no matter what
  // `classifyUpstream` does. It asserted the safe path and left the DANGEROUS one
  // (a real SDK error carrying a response body) untested. This project has paid for
  // that shape before: a check must simulate the dangerous mode, not merely make
  // the guard fire. So: every classification branch, each fed a real error of the
  // TYPE that branch exists for, each carrying the same sentinel.
  const LEAK_SENTINEL = 'SECRET-UPSTREAM-BODY-1234';
  it.each([
    [
      'an SDK APIError carrying a response body (the branch that CAN leak)',
      new Anthropic.APIError(
        429,
        { type: 'error', error: { type: 'rate_limit_error', message: LEAK_SENTINEL } },
        LEAK_SENTINEL,
        undefined,
      ),
      'upstream-error',
    ],
    [
      'an SDK connection error',
      new Anthropic.APIConnectionError({ message: LEAK_SENTINEL }),
      'upstream-error',
    ],
    ['an SDK connection timeout', new Anthropic.APIConnectionTimeoutError(), 'timeout'],
    ['an unrecognized error', new Error(LEAK_SENTINEL), 'unknown'],
  ])(
    'NEVER lets upstream text reach the mapped error — %s (ADR-016 D5)',
    (_label, upstream, expected) => {
      const classification = classifyUpstream(upstream);
      expect(classification).toBe(expected);

      const mapped = new ProviderUnavailableError(classification);
      // The message is a static literal keyed by the enum — assert BOTH that the
      // sentinel is absent AND that the message is exactly the enum's literal, so a
      // future edit that appends upstream detail fails here rather than leaking.
      expect(mapped.message).not.toContain(LEAK_SENTINEL);
      expect(mapped.message).toBe(`coach provider unavailable: ${expected}`);
      // Belt and braces: nothing anywhere on the thrown object carries it — a
      // `cause`, a copied field, or a stack that quoted the upstream message.
      expect(JSON.stringify({ ...mapped, message: mapped.message, stack: mapped.stack })).not.toContain(
        LEAK_SENTINEL,
      );
    },
  );
});

describe('extractReplyText', () => {
  it('returns the first text block on a normal completion', () => {
    const reply = extractReplyText({
      content: [{ type: 'text', text: 'Merhaba! Nasılsınız?', citations: null }],
      stop_reason: 'end_turn',
    });
    expect(reply).toEqual({ text: 'Merhaba! Nasılsınız?' });
  });

  it('treats a `refusal` stop reason as an outage even WITH text present', () => {
    // The text block is the point (reviewed S042). The original version passed
    // `content: []`, which made it byte-identical in effect to the next test — both
    // exercised the missing-text-block branch, and the refusal condition itself was
    // never isolated. A mutant that deleted `stop_reason === 'refusal'` survived,
    // meaning a refusal that CARRIES text would have been handed to the user as a
    // coach reply — the opposite of ADR-028 D3's stated behaviour, with a green
    // suite. Refusal must lose to the outage path even when there is text to return.
    expect(
      classificationOfThrow(() =>
        extractReplyText({
          content: [{ type: 'text', text: 'I cannot help with that.', citations: null }],
          stop_reason: 'refusal',
        }),
      ),
    ).toBe('upstream-error');
  });

  it('treats a `refusal` stop reason as an outage with no text block either', () => {
    expect(
      classificationOfThrow(() => extractReplyText({ content: [], stop_reason: 'refusal' })),
    ).toBe('upstream-error');
  });

  it('DELIVERS a `max_tokens`-truncated reply rather than treating it as an outage', () => {
    // Reviewed S042: this path was untested, so the behaviour was an accident rather
    // than a decision. Pinning the decision: a reply cut off at COACH_MAX_TOKENS is
    // still a warm, usable turn, and discarding it would turn a long answer into a
    // fake outage that also burns the user's cap. It is DELIVERED — and because the
    // handler's crisis post-filter now scans the reply IN FULL (no user-input
    // truncation cap), a truncated reply is scanned end-to-end like any other.
    expect(
      extractReplyText({
        content: [{ type: 'text', text: 'Bunu birlikte düşünelim; ilk olarak', citations: null }],
        stop_reason: 'max_tokens',
      }),
    ).toEqual({ text: 'Bunu birlikte düşünelim; ilk olarak' });
  });

  it('treats a completion with no text block as `upstream-error`', () => {
    expect(
      classificationOfThrow(() => extractReplyText({ content: [], stop_reason: 'end_turn' })),
    ).toBe('upstream-error');
  });
});

describe('AnthropicCoachProvider', () => {
  const savedKey = process.env.LLM_API_KEY;
  afterEach(() => {
    if (savedKey === undefined) {
      delete process.env.LLM_API_KEY;
    } else {
      process.env.LLM_API_KEY = savedKey;
    }
  });

  it('fails closed `unconfigured` when LLM_API_KEY is absent (deploy-safe)', async () => {
    delete process.env.LLM_API_KEY;
    const provider = new AnthropicCoachProvider();
    await expect(provider.generateReply(SAMPLE_REQUEST)).rejects.toMatchObject({
      classification: 'unconfigured',
    });
  });

  it('fails closed `unconfigured` on an empty-string key', async () => {
    process.env.LLM_API_KEY = '';
    const provider = new AnthropicCoachProvider();
    await expect(provider.generateReply(SAMPLE_REQUEST)).rejects.toMatchObject({
      classification: 'unconfigured',
    });
  });
});

/**
 * Every string reachable from a thrown value, following `cause` chains and own
 * properties, and reading `Error`'s NON-ENUMERABLE `message`/`stack` explicitly.
 *
 * Reviewed S042 — this exists because the first version of the leak assertion used
 * `JSON.stringify`, and a mutation proved that useless: `Error`'s own properties are
 * non-enumerable, so `JSON.stringify({cause: someError})` is `{"cause":{}}`. A
 * mutant that attached the upstream error as `cause` leaked the response body and
 * the test stayed GREEN. Only the mutant told the two apart.
 */
function collectStrings(value: unknown, seen = new Set<unknown>()): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value !== 'object') return String(value);
  if (seen.has(value)) return '';
  seen.add(value);

  const parts: string[] = [];
  if (value instanceof Error) {
    parts.push(value.message, value.stack ?? '', value.name);
    parts.push(collectStrings((value as { cause?: unknown }).cause, seen));
  }
  for (const key of Object.keys(value as Record<string, unknown>)) {
    parts.push(key, collectStrings((value as Record<string, unknown>)[key], seen));
  }
  return parts.join('\u0000');
}

describe('AnthropicCoachProvider — the leak guarantee at the THROW SITE', () => {
  // The tests above prove the MAPPING is leak-free. They do not prove the provider
  // only ever throws the mapped error — and that is where ADR-016 D5's guarantee
  // actually lives ("no response body, SDK message, or stack can reach a log
  // THROUGH THIS ADAPTER"). Reviewed S042: without this, an edit at the throw site
  // (`throw new Error('upstream: ' + error.message)`) would leak with every test
  // above still green. Spying on the SDK prototype keeps `instanceof` intact, which
  // a module-level mock would destroy — and `instanceof` is what classifyUpstream
  // branches on.
  const LEAK = 'SECRET-RESPONSE-BODY-9876';
  // REAL enum members (provider-port.ts COACH_PERSONA_IDS / _LANGUAGES / _REGISTERS)
  // and NO `as unknown as` cast — reviewed S042. The first draft used invented
  // values ('perisi'/'siz') behind a cast, so `buildPersonaSystemPrompt` threw
  // INSIDE the try block and every case classified as `unknown` without the SDK
  // ever being reached. The leak assertions were scanning an error the adapter
  // raised about its own arguments. A cast that silences the compiler on a test
  // fixture silences the one check that would have caught it.
  const req: CoachProviderRequest = {
    personaId: 'coach',
    language: 'tr',
    register: 'tr-respectful',
    messages: [{ role: 'user', text: 'merhaba' }],
  };

  beforeEach(() => {
    process.env.LLM_API_KEY = 'test-key-not-a-real-secret';
  });
  afterEach(() => {
    vi.restoreAllMocks();
    delete process.env.LLM_API_KEY;
  });

  it.each([
    [
      'an SDK APIError whose body and message both carry the sentinel',
      new Anthropic.APIError(
        500,
        { type: 'error', error: { type: 'api_error', message: LEAK } },
        LEAK,
        undefined,
      ),
      'upstream-error',
    ],
    ['an SDK connection error', new Anthropic.APIConnectionError({ message: LEAK }), 'upstream-error'],
    ['a bare error', new Error(LEAK), 'unknown'],
  ])(
    'maps %s to a leak-free ProviderUnavailableError',
    async (_label, sdkError, expectedClass) => {
    const create = vi
      .spyOn(Anthropic.Messages.prototype, 'create')
      .mockRejectedValue(sdkError);

    const thrown = await new AnthropicCoachProvider()
      .generateReply(req)
      .then(() => undefined as unknown as Error)
      .catch((e: Error) => e);

    expect(create).toHaveBeenCalledTimes(1); // the SDK was REACHED, not short-circuited
    expect(thrown).toBeInstanceOf(ProviderUnavailableError);
    expect((thrown as ProviderUnavailableError).classification).toBe(expectedClass);
    expect(collectStrings(thrown)).not.toContain(LEAK);
    },
  );

  it('reads the key at REQUEST time — a key set after import still works', async () => {
    // Kills the module-load mutant: if `LLM_API_KEY` were captured at import, this
    // would throw `unconfigured` (vitest imports the module before `beforeEach`
    // sets the env var) and no amount of absent-key testing would notice.
    // This is also the adapter's only happy-path assertion.
    const create = vi
      .spyOn(Anthropic.Messages.prototype, 'create')
      .mockResolvedValue({
        content: [{ type: 'text', text: 'Merhaba.', citations: null }],
        stop_reason: 'end_turn',
      } as unknown as Awaited<ReturnType<Anthropic.Messages['create']>>);

    await expect(new AnthropicCoachProvider().generateReply(req)).resolves.toEqual({
      text: 'Merhaba.',
    });
    expect(create).toHaveBeenCalledTimes(1);
  });

  it('fails closed with `unconfigured` when the secret is absent, without calling the API', async () => {
    delete process.env.LLM_API_KEY;
    const create = vi.spyOn(Anthropic.Messages.prototype, 'create');

    const thrown = await new AnthropicCoachProvider()
      .generateReply(req)
      .then(() => undefined as unknown as ProviderUnavailableError)
      .catch((e: ProviderUnavailableError) => e);

    expect(thrown.classification).toBe('unconfigured');
    // The point of reading the key at REQUEST time: no upstream call is attempted,
    // so a keyless deploy costs nothing and cannot half-charge a cap.
    expect(create).not.toHaveBeenCalled();
  });
});
