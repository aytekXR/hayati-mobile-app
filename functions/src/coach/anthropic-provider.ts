// The M5.3 live coach adapter (ADR-016 Decision 5, ADR-017 Decision 7). Implements
// the provider-agnostic `CoachProvider` port with the official Anthropic SDK
// (`@anthropic-ai/sdk`, the TypeScript-native client — never a raw fetch shim).
//
// This file is the ONLY place a vendor is named. It inherits two obligations from
// the port (provider-port.ts):
//   1. It NEVER copies upstream text into an error. Every failure is mapped to a
//      `ProviderUnavailableError(classification)` whose message is derived from the
//      closed classification enum — so no response body, SDK message, or stack can
//      reach a log through this adapter (Decision 5). `classifyUpstream` branches on
//      the error's TYPE only; it never reads `.message`.
//   2. It does NO crisis filtering — the handler post-filter already runs all three
//      lexicons over the reply (coach-proxy.ts step 7). This adapter only generates.
//
// The API key is read at REQUEST time from the `LLM_API_KEY` secret (the
// RC_WEBHOOK_TOKEN precedent). Absent key → fail-closed `unconfigured`, so wiring
// this provider into `coachProxy` is safe even before the secret exists (the
// callable answers the honest `unavailable` state until it is set).
//
// Thinking is DISABLED: a coach reply is a brief, warm conversational turn, not a
// hard reasoning task — the safety spine lives in the crisis detector, not here.
// Disabling keeps latency low (chat UX) and cost predictable (thinking tokens bill
// as output). Switch `COACH_MODEL` to change tiers — the seam is provider-agnostic
// and the choice is one line (Session 037: Sonnet 5, the founder's cost/quality
// balance; Haiku 4.5 is cheaper, Opus 4.8 higher quality).

import Anthropic from '@anthropic-ai/sdk';

import { buildPersonaSystemPrompt } from './persona-prompts';
import {
  CoachProvider,
  CoachProviderReply,
  CoachProviderRequest,
  ProviderUnavailableClassification,
  ProviderUnavailableError,
} from './provider-port';

/** The coach model (Session 037 founder choice). One-line swap; seam is agnostic. */
export const COACH_MODEL = 'claude-sonnet-5';
/** A coach reply is brief (the safety preamble mandates it); this bounds spend. */
export const COACH_MAX_TOKENS = 1024;
/** Client-level timeout (ms) — well under the callable's own budget, so a slow
 *  upstream maps to `timeout` rather than hanging the function. */
const CLIENT_TIMEOUT_MS = 20_000;
/** One transient retry; the handler refunds on the final failure anyway. */
const CLIENT_MAX_RETRIES = 1;

/**
 * Map an SDK/transport error to the port's classification enum by TYPE ONLY —
 * never by reading the error's message (Decision 5). A connection timeout is
 * `timeout`; any other Anthropic API error (4xx/5xx/network) is `upstream-error`;
 * anything unrecognized is `unknown`. The caller wraps the result in a
 * `ProviderUnavailableError`, whose message is a static literal keyed by this enum
 * — so upstream text has no path into a log.
 */
export function classifyUpstream(error: unknown): ProviderUnavailableClassification {
  if (error instanceof Anthropic.APIConnectionTimeoutError) {
    return 'timeout';
  }
  if (error instanceof Anthropic.APIError) {
    return 'upstream-error';
  }
  return 'unknown';
}

/**
 * Extract the reply text from a completed message. A `refusal` stop reason (or any
 * completion with no text block) is NOT a crisis — the crisis pre-scan already ran
 * before the reserve — so it is treated as an outage: throw `upstream-error`, which
 * the handler maps to `unavailable` and refunds the reserved cap. Takes only the
 * two fields it needs so it is unit-testable without constructing a full SDK message.
 */
export function extractReplyText(
  message: Pick<Anthropic.Message, 'content' | 'stop_reason'>,
): CoachProviderReply {
  const textBlock = message.content.find(
    (block): block is Anthropic.TextBlock => block.type === 'text',
  );
  if (message.stop_reason === 'refusal' || textBlock === undefined) {
    throw new ProviderUnavailableError('upstream-error');
  }
  return { text: textBlock.text };
}

/**
 * The live coach provider. Reads `LLM_API_KEY` at request time, builds the persona
 * system prompt from the closed enums (no user content reaches prompt construction —
 * ADR-017 D7), calls the Anthropic Messages API with thinking disabled, and returns
 * the reply text. Every failure becomes a classification-only `ProviderUnavailableError`.
 */
export class AnthropicCoachProvider implements CoachProvider {
  async generateReply(req: CoachProviderRequest): Promise<CoachProviderReply> {
    const apiKey = process.env.LLM_API_KEY;
    if (apiKey === undefined || apiKey.length === 0) {
      throw new ProviderUnavailableError('unconfigured');
    }

    const client = new Anthropic({
      apiKey,
      timeout: CLIENT_TIMEOUT_MS,
      maxRetries: CLIENT_MAX_RETRIES,
    });

    let message: Anthropic.Message;
    try {
      message = await client.messages.create({
        model: COACH_MODEL,
        max_tokens: COACH_MAX_TOKENS,
        thinking: { type: 'disabled' },
        system: buildPersonaSystemPrompt({
          personaId: req.personaId,
          language: req.language,
          register: req.register,
        }),
        messages: req.messages.map((m) => ({ role: m.role, content: m.text })),
      });
    } catch (error) {
      // TYPE-only classification — never copy upstream text (Decision 5).
      throw new ProviderUnavailableError(classifyUpstream(error));
    }

    return extractReplyText(message);
  }
}
