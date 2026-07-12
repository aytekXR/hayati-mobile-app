// Unit tests for the persona system-prompt scaffolds (ADR-017 Decision 7):
// totality over the full 3×3×4 enum product (36 combos), determinism (the
// static-literal / zero-interpolation guarantee), per-enum content markers, the
// not-therapy line + language directive in every language, and the mismatched
// pair (language 'en' + register 'tr-playful') where the language directive
// wins. Matches the coach-help-content unit-test style.
import { describe, expect, it } from 'vitest';

import {
  buildPersonaSystemPrompt,
  PERSONA_BLOCKS,
  REGISTER_BLOCKS,
  SAFETY_PREAMBLE,
} from '../../src/coach/persona-prompts';
import {
  COACH_LANGUAGES,
  COACH_PERSONA_IDS,
  COACH_REGISTERS,
  CoachLanguage,
} from '../../src/coach/provider-port';

/** A distinctive not-therapy substring per language (the ★ safety line). */
const NOT_THERAPY: Record<CoachLanguage, string> = {
  en: 'not therapy',
  tr: 'terapi değildir',
  ar: 'ليس علاجًا',
};

/** The explicit reply-language directive per language. */
const LANGUAGE_DIRECTIVE: Record<CoachLanguage, string> = {
  en: 'Respond only in English',
  tr: 'Yalnızca Türkçe yanıt ver',
  ar: 'أجب بالعربية فقط',
};

/** The full 36-combo product, materialized once. */
const COMBOS = COACH_PERSONA_IDS.flatMap((personaId) =>
  COACH_LANGUAGES.flatMap((language) =>
    COACH_REGISTERS.map((register) => ({ personaId, language, register })),
  ),
);

describe('buildPersonaSystemPrompt — totality over the 3×3×4 product', () => {
  it('produces a non-empty prompt for every one of the 36 combos', () => {
    expect(COMBOS).toHaveLength(36);
    for (const combo of COMBOS) {
      expect(buildPersonaSystemPrompt(combo).length).toBeGreaterThan(50);
    }
  });

  it('is deterministic — same input yields byte-identical output (static, no interpolation)', () => {
    for (const combo of COMBOS) {
      expect(buildPersonaSystemPrompt(combo)).toBe(buildPersonaSystemPrompt(combo));
    }
  });

  it('embeds the persona block and the register tone block for its keys', () => {
    for (const combo of COMBOS) {
      const prompt = buildPersonaSystemPrompt(combo);
      expect(prompt).toContain(PERSONA_BLOCKS[combo.personaId][combo.language]);
      expect(prompt).toContain(REGISTER_BLOCKS[combo.register]);
    }
  });

  it('carries the not-therapy safety line + language directive of its language', () => {
    for (const combo of COMBOS) {
      const prompt = buildPersonaSystemPrompt(combo);
      expect(prompt).toContain(SAFETY_PREAMBLE[combo.language]);
      expect(prompt).toContain(NOT_THERAPY[combo.language]);
      expect(prompt).toContain(LANGUAGE_DIRECTIVE[combo.language]);
    }
  });
});

describe('buildPersonaSystemPrompt — the not-therapy line, per language', () => {
  it.each(COACH_LANGUAGES)('SAFETY_PREAMBLE[%s] contains its not-therapy substring', (language) => {
    expect(SAFETY_PREAMBLE[language]).toContain(NOT_THERAPY[language]);
    expect(SAFETY_PREAMBLE[language]).toContain(LANGUAGE_DIRECTIVE[language]);
  });
});

describe('buildPersonaSystemPrompt — mismatched language/register pair', () => {
  it("language 'en' + register 'tr-playful' stays coherent: the EN preamble + directive win", () => {
    const prompt = buildPersonaSystemPrompt({
      personaId: 'coach',
      language: 'en',
      register: 'tr-playful',
    });

    expect(prompt.length).toBeGreaterThan(50);
    // The language directive follows the LANGUAGE, not the register.
    expect(prompt).toContain(SAFETY_PREAMBLE.en);
    expect(prompt).toContain(LANGUAGE_DIRECTIVE.en);
    expect(prompt).not.toContain(LANGUAGE_DIRECTIVE.tr);
    // The register tone note is still present (the register block wins on tone).
    expect(prompt).toContain(REGISTER_BLOCKS['tr-playful']);
  });
});
