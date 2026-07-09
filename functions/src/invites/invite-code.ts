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
