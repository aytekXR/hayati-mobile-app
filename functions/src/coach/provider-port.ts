// Provider-agnostic coach port for the M5.1 seam (ADR-016 Decision 5). NO vendor
// is chosen and none is needed: the shape is OURS — deliberately smaller than any
// provider API so any of them can adapt to it. This slice makes ZERO live calls
// anywhere (test-suite.md §4); the only providers here are the fail-closed
// production default and the fixture replay used by tests. The persona
// system-prompt scaffold is M5.2 scope — this file defines only the CLOSED type
// surface and the port contract.

/**
 * The persona ids (closed enum). The single source of truth for both the compile-
 * time union and the runtime validator (coach-core validateCoachRequest).
 */
export const COACH_PERSONA_IDS = ['coach', 'dateGenie', 'giftGenie'] as const;
export type CoachPersonaId = (typeof COACH_PERSONA_IDS)[number];

/** The coach languages (closed enum). */
export const COACH_LANGUAGES = ['tr', 'ar', 'en'] as const;
export type CoachLanguage = (typeof COACH_LANGUAGES)[number];

/**
 * The brandkit register ids (closed enum). Closed at the PORT shape, validated at
 * input: an open `string` flowing toward a future system-prompt position is a
 * prompt-injection seam, shut BEFORE any adapter exists (Decision 1/5 finding).
 */
export const COACH_REGISTERS = ['tr-playful', 'tr-respectful', 'ar-gulf-respectful', 'en-neutral'] as const;
export type CoachRegister = (typeof COACH_REGISTERS)[number];

export interface CoachProviderMessage {
  role: 'user' | 'assistant';
  text: string;
}

/** The port request — ours, not any vendor's (ADR-016 Decision 5). */
export interface CoachProviderRequest {
  personaId: CoachPersonaId;
  language: CoachLanguage;
  register: CoachRegister;
  messages: ReadonlyArray<CoachProviderMessage>;
}

export interface CoachProviderReply {
  text: string;
}

/**
 * The coach provider port. A live adapter (M5.2/M5.3) implements this behind the
 * `LLM_API_KEY` secret read at request time (the RC_WEBHOOK_TOKEN precedent), and
 * inherits two obligations from the ADR: the handler post-filter already runs all
 * three lexicons over the reply (off-language replies), and the adapter must map
 * upstream errors to the classification enum below WITHOUT ever copying upstream
 * text into an error message.
 */
export interface CoachProvider {
  generateReply(req: CoachProviderRequest): Promise<CoachProviderReply>;
}

/**
 * How a provider became unavailable (ADR-016 Decision 5). The ONLY thing a
 * ProviderUnavailableError carries — its message is derived from this enum, never
 * from upstream text.
 */
export const PROVIDER_UNAVAILABLE_CLASSIFICATIONS = [
  'unconfigured',
  'timeout',
  'upstream-error',
  'unknown',
] as const;
export type ProviderUnavailableClassification = (typeof PROVIDER_UNAVAILABLE_CLASSIFICATIONS)[number];

/**
 * The static per-classification messages. Each is a HARDCODED literal selected by
 * the enum key — never interpolated from a constructor argument — so no upstream
 * response text can ever reach a log through this error's message. A future
 * adapter writing `new ProviderUnavailableError(\`upstream 400: ${body}\`)` does
 * not compile: the constructor accepts ONLY the enum.
 */
export const PROVIDER_UNAVAILABLE_MESSAGES: Readonly<Record<ProviderUnavailableClassification, string>> = {
  unconfigured: 'coach provider unavailable: unconfigured',
  timeout: 'coach provider unavailable: timeout',
  'upstream-error': 'coach provider unavailable: upstream-error',
  unknown: 'coach provider unavailable: unknown',
};

/**
 * The honest "coach unavailable" signal (ADR-016 Decision 5). Carries a
 * classification enum ONLY; its `message` is a static string derived from that
 * enum and it NEVER embeds free text. An outage is not a crisis, so the handler
 * maps this to `unavailable` (refunding the reserved cap), not to the help path.
 */
export class ProviderUnavailableError extends Error {
  readonly classification: ProviderUnavailableClassification;

  constructor(classification: ProviderUnavailableClassification) {
    super(PROVIDER_UNAVAILABLE_MESSAGES[classification]);
    this.name = 'ProviderUnavailableError';
    this.classification = classification;
  }
}

/**
 * The production DEFAULT for this slice (ADR-016 Decision 5): always fail-closed
 * `unconfigured` — no key, no provider, honest unavailable state. This is what
 * lets `coachProxy` DEPLOY safely before any provider decision is made
 * (the REVENUECAT_IOS_API_KEY fail-closed pattern).
 */
export class UnconfiguredCoachProvider implements CoachProvider {
  async generateReply(): Promise<CoachProviderReply> {
    throw new ProviderUnavailableError('unconfigured');
  }
}

/** One recorded fixture outcome: a reply to return, or a classification to throw. */
export type CoachFixtureEntry = { text: string } | { throws: ProviderUnavailableClassification };

/**
 * Test-only provider (ADR-016 Decision 5): replays recorded fixture entries in
 * order and records an ordered CALL LOG the safety tests assert against ("zero
 * calls on crisis input"). A `{throws}` entry raises the corresponding
 * ProviderUnavailableError (pinning the `unavailable` + refund path). Past the
 * end of the entry list it reuses the LAST entry, so a single-entry provider
 * answers every call identically.
 */
export class FixtureCoachProvider implements CoachProvider {
  /** The ordered log of requests this provider was called with. */
  readonly calls: CoachProviderRequest[] = [];
  private index = 0;

  constructor(private readonly entries: readonly CoachFixtureEntry[]) {
    if (entries.length === 0) {
      throw new Error('FixtureCoachProvider requires at least one fixture entry');
    }
  }

  async generateReply(req: CoachProviderRequest): Promise<CoachProviderReply> {
    this.calls.push(req);
    const entry = this.entries[Math.min(this.index, this.entries.length - 1)];
    this.index += 1;
    if ('throws' in entry) {
      throw new ProviderUnavailableError(entry.throws);
    }
    return { text: entry.text };
  }
}
