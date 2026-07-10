import { randomInt } from 'node:crypto';

/**
 * Pairing-code charset: uppercase A–Z + digits, minus the glyphs that are
 * ambiguous when read aloud or retyped from a WhatsApp message (0/O, 1/I/L).
 * 31 characters × length 8 ≈ 8.5e11 codes — collisions are handled by
 * retry-inside-transaction in the invite service, not by praying.
 */
export const INVITE_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

export const INVITE_CODE_LENGTH = 8;

/** Returns a uniform integer in [0, maxExclusive). Injectable for tests. */
export type RandomIndex = (maxExclusive: number) => number;

const secureRandomIndex: RandomIndex = (maxExclusive) => randomInt(maxExclusive);

/**
 * Generates one pairing code. `random` defaults to node:crypto's unbiased
 * [randomInt]; tests inject a rigged source to pin determinism and to force
 * collisions in the service-level suite.
 */
export function generateInviteCode(random: RandomIndex = secureRandomIndex): string {
  let code = '';
  for (let i = 0; i < INVITE_CODE_LENGTH; i += 1) {
    code += INVITE_CODE_ALPHABET[random(INVITE_CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * The single format check for a pairing code, derived from the alphabet +
 * length above so there is no second hardcoded regex to drift (M2.3 moved this
 * here from invite-preview.ts: BOTH the zero-auth preview and the join Function
 * validate codes, so the shape has ONE owner).
 */
const INVITE_CODE_PATTERN = new RegExp(
  `^[${INVITE_CODE_ALPHABET}]{${INVITE_CODE_LENGTH}}$`,
);

/**
 * Normalizes a code as a human would deliver it: codes are read aloud or
 * retyped from a WhatsApp message, so surrounding whitespace is trimmed and
 * lowercase is upper-cased. Returns the normalized code, or null when the input
 * can't be a real code (wrong length / an out-of-alphabet glyph) — callers
 * treat null as "no such code" WITHOUT a Firestore read (no enumeration oracle).
 */
export function normalizeInviteCode(raw: string): string | null {
  const normalized = raw.trim().toUpperCase();
  return INVITE_CODE_PATTERN.test(normalized) ? normalized : null;
}
