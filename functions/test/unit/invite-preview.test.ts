// Pure unit tests for the preview's code-format helper — no emulator required.
// The regex is derived from invite-code.ts (single source of truth), so these
// pin the normalize-then-validate contract the endpoint relies on.
import fc from 'fast-check';
import { describe, expect, it } from 'vitest';

import {
  INVITE_CODE_ALPHABET,
  INVITE_CODE_LENGTH,
  generateInviteCode,
} from '../../src/invites/invite-code';
import { normalizeInviteCode } from '../../src/invites/invite-preview';

describe('normalizeInviteCode', () => {
  it('accepts any well-formed generated code and returns it uppercased', () => {
    fc.assert(
      fc.property(fc.array(fc.nat(), { minLength: 1 }), (indexes) => {
        const code = generateInviteCode(
          (max) => indexes[0] % max, // deterministic single-char fill is enough
        );
        expect(normalizeInviteCode(code)).toBe(code);
      }),
    );
  });

  it('trims surrounding whitespace and uppercases lowercase input', () => {
    const code = generateInviteCode(() => 0); // 'AAAAAAAA'
    expect(normalizeInviteCode(`  ${code.toLowerCase()}\n`)).toBe(code);
  });

  it('rejects codes of the wrong length', () => {
    expect(normalizeInviteCode('ABCDEFG')).toBeNull(); // 7
    expect(normalizeInviteCode('ABCDEFGHJ')).toBeNull(); // 9
    expect(normalizeInviteCode('')).toBeNull();
  });

  it('rejects the ambiguous glyphs excluded from the alphabet', () => {
    for (const ambiguous of ['0', 'O', '1', 'I', 'L']) {
      const code = ambiguous.repeat(INVITE_CODE_LENGTH);
      // 'O','I','L' uppercase to themselves; each is outside the alphabet.
      expect(INVITE_CODE_ALPHABET).not.toContain(ambiguous);
      expect(normalizeInviteCode(code)).toBeNull();
    }
  });

  it('rejects non-alphabet punctuation', () => {
    expect(normalizeInviteCode('ABCD-234')).toBeNull();
    expect(normalizeInviteCode('ABCD 234')).toBeNull();
  });
});
