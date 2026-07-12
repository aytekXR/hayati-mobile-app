// Unit tests for the static coach help/disclaimer copy (ADR-016 Decision 4):
// all three languages present, EN fallback on a junk language field, and the
// hard rule — NO hotline phone numbers ship in this slice.
import { describe, expect, it } from 'vitest';

import { disclaimer, helpResponse } from '../../src/coach/help-content';

const LANGUAGES = ['tr', 'ar', 'en'] as const;

describe('helpResponse — localized, warm, non-clinical', () => {
  it.each(LANGUAGES)('returns non-empty copy for %s', (language) => {
    expect(helpResponse(language).length).toBeGreaterThan(20);
  });

  it('gives a distinct string per language', () => {
    const set = new Set(LANGUAGES.map((l) => helpResponse(l)));
    expect(set.size).toBe(3);
  });

  it.each([['junk'], ['fr'], [''], [null], [undefined], [42], [{}]])(
    'falls back to EN for a junk language field (%j)',
    (junk) => {
      expect(helpResponse(junk as unknown)).toBe(helpResponse('en'));
    },
  );
});

describe('disclaimer — "not therapy" copy', () => {
  it.each(LANGUAGES)('returns non-empty copy for %s', (language) => {
    expect(disclaimer(language).length).toBeGreaterThan(20);
  });

  it('falls back to EN on junk', () => {
    expect(disclaimer('klingon' as unknown)).toBe(disclaimer('en'));
  });
});

describe('HARD RULE — no hotline phone numbers ship (Decision 4)', () => {
  const allCopy = [...LANGUAGES.map(helpResponse), ...LANGUAGES.map(disclaimer)];

  it.each(allCopy.map((c, i) => [i, c] as const))('copy #%i contains no phone-number-shaped digit run', (_i, copy) => {
    expect(copy).not.toMatch(/\d{3,}/);
  });

  it('names the universal emergency route in words (EN), not a number', () => {
    expect(helpResponse('en').toLowerCase()).toContain('local emergency');
  });
});
