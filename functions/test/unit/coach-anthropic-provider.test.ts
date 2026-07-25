// Unit tests for the M5.3 live adapter (anthropic-provider.ts). The two
// safety-bearing pure helpers are exercised directly — the SDK network call itself
// is integration territory, out of unit scope. The load-bearing assertion is the
// ADR-016 D5 invariant: no upstream text can reach a log through the mapped error.
import Anthropic from '@anthropic-ai/sdk';
import { afterEach, describe, expect, it } from 'vitest';

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

  it('NEVER lets upstream text reach the mapped error message (ADR-016 D5)', () => {
    // The whole point of the port's enum-only constructor: even an error carrying
    // a secret upstream string produces a static, leak-free message.
    const upstream = new Error('SECRET-UPSTREAM-BODY-1234');
    const mapped = new ProviderUnavailableError(classifyUpstream(upstream));
    expect(mapped.message).not.toContain('SECRET-UPSTREAM-BODY-1234');
    expect(mapped.message).toBe('coach provider unavailable: unknown');
  });
});

describe('extractReplyText', () => {
  it('returns the first text block on a normal completion', () => {
    const reply = extractReplyText({
      content: [{ type: 'text', text: 'Merhaba! Nasılsınız?', citations: null }],
      stop_reason: 'end_turn',
    });
    expect(reply).toEqual({ text: 'Merhaba! Nasılsınız?' });
  });

  it('treats a `refusal` stop reason as an outage (`upstream-error`), not a crisis', () => {
    expect(
      classificationOfThrow(() => extractReplyText({ content: [], stop_reason: 'refusal' })),
    ).toBe('upstream-error');
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
