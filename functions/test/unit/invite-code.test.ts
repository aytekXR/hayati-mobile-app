// Property tests for the pairing-code generator (test-suite.md §3: charset /
// length / collision behavior). Pure unit — no emulator required.
import fc from 'fast-check';
import { describe, expect, it } from 'vitest';

import {
  INVITE_CODE_ALPHABET,
  INVITE_CODE_LENGTH,
  generateInviteCode,
} from '../../src/invites/invite-code';

/** A rigged random source that replays the given indexes, then wraps. */
function riggedRandom(indexes: number[]): (maxExclusive: number) => number {
  let i = 0;
  return (maxExclusive) => {
    const value = indexes[i % indexes.length] % maxExclusive;
    i += 1;
    return value;
  };
}

describe('INVITE_CODE_ALPHABET', () => {
  it('has 31 unambiguous characters (no 0/O/1/I/L, resume-prompt fallback spec)', () => {
    expect(INVITE_CODE_ALPHABET).toHaveLength(31);
    expect(new Set(INVITE_CODE_ALPHABET).size).toBe(31);
    for (const ambiguous of ['0', 'O', '1', 'I', 'L', 'l']) {
      expect(INVITE_CODE_ALPHABET).not.toContain(ambiguous);
    }
    // Uppercase A–Z + digits only: codes survive being read aloud or typed
    // from a WhatsApp message without case or glyph confusion.
    expect(INVITE_CODE_ALPHABET).toMatch(/^[A-Z2-9]+$/);
  });
});

describe('generateInviteCode', () => {
  it('always produces codes of the fixed length drawn from the alphabet', () => {
    fc.assert(
      fc.property(
        fc.array(fc.nat({ max: 1000 }), { minLength: 1, maxLength: 64 }),
        (indexes) => {
          const code = generateInviteCode(riggedRandom(indexes));
          expect(code).toHaveLength(INVITE_CODE_LENGTH);
          expect(code).toMatch(
            new RegExp(`^[${INVITE_CODE_ALPHABET}]{${INVITE_CODE_LENGTH}}$`),
          );
        },
      ),
    );
  });

  it('uses the injected random source deterministically', () => {
    const indexes = [0, 1, 2, 3, 4, 5, 6, 7];
    expect(generateInviteCode(riggedRandom(indexes))).toBe(
      indexes.map((i) => INVITE_CODE_ALPHABET[i]).join(''),
    );
  });

  it('can reach every character of the alphabet', () => {
    const seen = new Set<string>();
    for (let i = 0; i < INVITE_CODE_ALPHABET.length; i += 1) {
      seen.add(generateInviteCode(() => i)[0]);
    }
    expect(seen.size).toBe(INVITE_CODE_ALPHABET.length);
  });

  it('is collision-resistant at our scale with the secure default source', () => {
    // 31^8 ≈ 8.5e11 codes; 10k draws colliding would be a broken generator,
    // not bad luck (birthday bound ≈ 6e-5 for 10k draws).
    const codes = new Set<string>();
    for (let i = 0; i < 10_000; i += 1) {
      codes.add(generateInviteCode());
    }
    expect(codes.size).toBe(10_000);
  });
});
