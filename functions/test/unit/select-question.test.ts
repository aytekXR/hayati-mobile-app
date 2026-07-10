import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

import { NoSelectableQuestionError, selectQuestion } from '../../src/rollover/select-question';
import type { Question, QuestionPack } from '../../src/rollover/pack-loader';

// M3.2 deterministic selection core (ADR-011 decision 4): pure function of
// (pack, days-history). First unseen evergreen question in pack authoring
// order; once the pack is exhausted, recycle by minimum times-assigned with
// pack order breaking ties. seasonalWindow questions are excluded entirely
// (documented evergreen-only policy). Register is a pack-level property, so
// "register honored" holds by construction: the result always comes from the
// configured pack.

function q(id: string, seasonalWindow?: string): Question {
  return { id, category: 'deep', depth: 2, text: `t-${id}`, seasonalWindow };
}

function pack(questions: Question[], version = 1): QuestionPack {
  return { packId: 'test_tr', version, locale: 'tr', register: 'neutral', questions };
}

const FIVE = pack([q('a'), q('b'), q('c'), q('d'), q('e')]);

describe('selectQuestion', () => {
  it('picks the first question of a fresh pack (empty history)', () => {
    expect(selectQuestion(FIVE, []).id).toBe('a');
  });

  it('picks the first UNSEEN question in pack order, not history order', () => {
    expect(selectQuestion(FIVE, ['a']).id).toBe('b');
    // History order scrambled: c and a seen — the earliest unseen is b.
    expect(selectQuestion(FIVE, ['c', 'a']).id).toBe('b');
    expect(selectQuestion(FIVE, ['a', 'b', 'c', 'd']).id).toBe('e');
  });

  it('skips seasonal questions even when unseen (evergreen-only policy)', () => {
    const withSeasonal = pack([q('a'), q('ram', 'ramadan'), q('b')]);
    expect(selectQuestion(withSeasonal, ['a']).id).toBe('b');
  });

  it('recycles deterministically after exhaustion: minimum times-assigned, pack order on ties', () => {
    // Whole pack seen once -> counts all 1 -> earliest in pack order again.
    expect(selectQuestion(FIVE, ['a', 'b', 'c', 'd', 'e']).id).toBe('a');
    // Second cycle underway: a seen twice -> next minimum is b.
    expect(selectQuestion(FIVE, ['a', 'b', 'c', 'd', 'e', 'a']).id).toBe('b');
    // Uneven counts: c seen 3x, others 1x, b 2x -> minimum ties broken by pack order.
    expect(selectQuestion(FIVE, ['c', 'c', 'c', 'b', 'b', 'a', 'd', 'e']).id).toBe('a');
  });

  it('ignores history ids no longer in the pack (question removed in a later pack version)', () => {
    expect(selectQuestion(FIVE, ['gone', 'a']).id).toBe('b');
  });

  it('prefers a never-seen question added by a pack-version bump over recycling', () => {
    const v2 = pack([q('a'), q('b'), q('new')], 2);
    expect(selectQuestion(v2, ['a', 'b']).id).toBe('new');
  });

  it('throws NoSelectableQuestionError when every question is seasonal', () => {
    const allSeasonal = pack([q('r1', 'ramadan'), q('e1', 'eid')]);
    expect(() => selectQuestion(allSeasonal, [])).toThrowError(NoSelectableQuestionError);
    expect(() => selectQuestion(allSeasonal, [])).toThrowError(/test_tr/);
  });

  it('property: deterministic, always evergreen, and unseen-first', () => {
    const ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    fc.assert(
      fc.property(
        // Random subset of ids marked seasonal (never all six — covered above).
        fc.uniqueArray(fc.constantFrom(...ids.slice(0, 5)), { maxLength: 3 }),
        // Random history multiset over the ids plus strangers.
        fc.array(fc.constantFrom(...ids, 'zz'), { maxLength: 40 }),
        (seasonalIds, history) => {
          const p = pack(ids.map((id) => q(id, seasonalIds.includes(id) ? 'ramadan' : undefined)));
          const picked = selectQuestion(p, history);
          const evergreen = p.questions.filter((question) => question.seasonalWindow === undefined);
          // Same inputs -> same output (purity/determinism).
          expect(selectQuestion(p, [...history]).id).toBe(picked.id);
          // Always an evergreen member of the pack.
          expect(evergreen.some((question) => question.id === picked.id)).toBe(true);
          // If any evergreen question is unseen, the pick is the FIRST unseen in pack order.
          const seen = new Set(history);
          const firstUnseen = evergreen.find((question) => !seen.has(question.id));
          if (firstUnseen !== undefined) {
            expect(picked.id).toBe(firstUnseen.id);
          }
        },
      ),
    );
  });
});
