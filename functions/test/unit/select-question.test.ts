import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

import { NoSelectableQuestionError, selectQuestion } from '../../src/rollover/select-question';
import type { Question, QuestionPack } from '../../src/rollover/pack-loader';
import type { SeasonalWindow } from '../../src/rollover/seasonal-window';

// Deterministic selection core (ADR-011 decision 4 as amended by ADR-026 D4):
// pure function of (pack, days-history, dayKey). In order: in-window seasonal
// UNSEEN first, else evergreen (first unseen in pack order, then min
// times-assigned with pack order breaking ties), else recycle in-window
// seasonal, else throw. Out-of-window seasonal questions are excluded exactly
// as the evergreen-only policy excluded all of them. Register is a pack-level
// property, so "register honored" holds by construction: the result always
// comes from the configured pack.
//
// dayKeys used below come from functions/test/fixtures/seasonal-window-cases.json:
const IN_RAMADAN = '20260218'; // 1447-09-01
const IN_EID_FITR = '20260320'; // 1447-10-01
const NO_WINDOW = '20260401'; // 1447-10-13 — no window open
const IN_NEW_YEAR = '20261231';

function q(id: string, seasonalWindow?: SeasonalWindow): Question {
  return { id, category: 'deep', depth: 2, text: `t-${id}`, seasonalWindow };
}

function pack(questions: Question[], version = 1): QuestionPack {
  return { packId: 'test_tr', version, locale: 'tr', register: 'neutral', questions };
}

const FIVE = pack([q('a'), q('b'), q('c'), q('d'), q('e')]);

describe('selectQuestion — the evergreen core (unchanged by ADR-026)', () => {
  it('picks the first question of a fresh pack (empty history)', () => {
    expect(selectQuestion(FIVE, [], NO_WINDOW).id).toBe('a');
  });

  it('picks the first UNSEEN question in pack order, not history order', () => {
    expect(selectQuestion(FIVE, ['a'], NO_WINDOW).id).toBe('b');
    // History order scrambled: c and a seen — the earliest unseen is b.
    expect(selectQuestion(FIVE, ['c', 'a'], NO_WINDOW).id).toBe('b');
    expect(selectQuestion(FIVE, ['a', 'b', 'c', 'd'], NO_WINDOW).id).toBe('e');
  });

  it('recycles deterministically after exhaustion: minimum times-assigned, pack order on ties', () => {
    // Whole pack seen once -> counts all 1 -> earliest in pack order again.
    expect(selectQuestion(FIVE, ['a', 'b', 'c', 'd', 'e'], NO_WINDOW).id).toBe('a');
    // Second cycle underway: a seen twice -> next minimum is b.
    expect(selectQuestion(FIVE, ['a', 'b', 'c', 'd', 'e', 'a'], NO_WINDOW).id).toBe('b');
    // Uneven counts: c seen 3x, others 1x, b 2x -> minimum ties broken by pack order.
    expect(selectQuestion(FIVE, ['c', 'c', 'c', 'b', 'b', 'a', 'd', 'e'], NO_WINDOW).id).toBe('a');
  });

  it('ignores history ids no longer in the pack (question removed in a later pack version)', () => {
    expect(selectQuestion(FIVE, ['gone', 'a'], NO_WINDOW).id).toBe('b');
  });

  it('prefers a never-seen question added by a pack-version bump over recycling', () => {
    const v2 = pack([q('a'), q('b'), q('new')], 2);
    expect(selectQuestion(v2, ['a', 'b'], NO_WINDOW).id).toBe('new');
  });

  it('is unaffected by the dayKey when the pack carries no seasonal question', () => {
    // The no-op-in-practice claim, proven rather than asserted: every shipped
    // pack is evergreen-only, so ADR-026 must not move a single assignment.
    for (const dayKey of [NO_WINDOW, IN_RAMADAN, IN_EID_FITR, IN_NEW_YEAR]) {
      expect(selectQuestion(FIVE, ['a', 'c'], dayKey).id).toBe('b');
    }
  });
});

describe('selectQuestion — seasonal windows (ADR-026 D4)', () => {
  const MIXED = pack([q('a'), q('ram1', 'ramadan'), q('b'), q('ram2', 'ramadan')]);

  it('skips seasonal questions OUTSIDE their window, even when unseen', () => {
    expect(selectQuestion(MIXED, [], NO_WINDOW).id).toBe('a');
    expect(selectQuestion(MIXED, ['a'], NO_WINDOW).id).toBe('b');
  });

  it('skips a seasonal question whose window is open for a DIFFERENT tag', () => {
    expect(selectQuestion(MIXED, [], IN_EID_FITR).id).toBe('a');
  });

  it('prefers an unseen in-window seasonal question over an unseen evergreen one', () => {
    expect(selectQuestion(MIXED, [], IN_RAMADAN).id).toBe('ram1');
    expect(selectQuestion(MIXED, ['ram1'], IN_RAMADAN).id).toBe('ram2');
  });

  it('returns to the evergreen curriculum once the in-window stock is spent', () => {
    // The load-bearing "unseen" of D4 step 1: 2 Ramadan questions do not loop
    // for 30 days while the curriculum sits idle.
    expect(selectQuestion(MIXED, ['ram1', 'ram2'], IN_RAMADAN).id).toBe('a');
    expect(selectQuestion(MIXED, ['ram1', 'ram2', 'a'], IN_RAMADAN).id).toBe('b');
    // ...and keeps recycling evergreen rather than re-showing a seasonal one.
    expect(selectQuestion(MIXED, ['ram1', 'ram2', 'a', 'b'], IN_RAMADAN).id).toBe('a');
  });

  it('opens the right window per tag on the same pack', () => {
    const twoSeasons = pack([q('a'), q('f1', 'eid_fitr'), q('ny', 'new_year')]);
    expect(selectQuestion(twoSeasons, [], IN_EID_FITR).id).toBe('f1');
    expect(selectQuestion(twoSeasons, [], IN_NEW_YEAR).id).toBe('ny');
    expect(selectQuestion(twoSeasons, [], NO_WINDOW).id).toBe('a');
  });

  it('recycles in-window seasonal questions when the pack has no evergreen at all', () => {
    const allSeasonal = pack([q('r1', 'ramadan'), q('r2', 'ramadan')]);
    expect(selectQuestion(allSeasonal, [], IN_RAMADAN).id).toBe('r1');
    expect(selectQuestion(allSeasonal, ['r1', 'r2'], IN_RAMADAN).id).toBe('r1');
    expect(selectQuestion(allSeasonal, ['r1', 'r2', 'r1'], IN_RAMADAN).id).toBe('r2');
  });

  it('throws NoSelectableQuestionError for an all-seasonal pack OUTSIDE every window', () => {
    const allSeasonal = pack([q('r1', 'ramadan'), q('e1', 'eid_fitr')]);
    expect(() => selectQuestion(allSeasonal, [], NO_WINDOW)).toThrowError(
      NoSelectableQuestionError,
    );
    expect(() => selectQuestion(allSeasonal, [], NO_WINDOW)).toThrowError(/test_tr/);
    // The message names the day, because selectability is now date-dependent.
    expect(() => selectQuestion(allSeasonal, [], NO_WINDOW)).toThrowError(
      new RegExp(NO_WINDOW),
    );
  });

  it('property: deterministic, in-pack, window-respecting, and seasonal-unseen-first', () => {
    const ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    fc.assert(
      fc.property(
        // Random subset of ids marked ramadan (never all six — covered above).
        fc.uniqueArray(fc.constantFrom(...ids.slice(0, 5)), { maxLength: 3 }),
        // Random history multiset over the ids plus strangers.
        fc.array(fc.constantFrom(...ids, 'zz'), { maxLength: 40 }),
        fc.constantFrom(IN_RAMADAN, IN_EID_FITR, IN_NEW_YEAR, NO_WINDOW),
        (seasonalIds, history, dayKey) => {
          const p = pack(ids.map((id) => q(id, seasonalIds.includes(id) ? 'ramadan' : undefined)));
          const picked = selectQuestion(p, history, dayKey);
          const evergreen = p.questions.filter((question) => question.seasonalWindow === undefined);
          const inWindow =
            dayKey === IN_RAMADAN
              ? p.questions.filter((question) => question.seasonalWindow === 'ramadan')
              : [];
          // Same inputs -> same output (purity/determinism).
          expect(selectQuestion(p, [...history], dayKey).id).toBe(picked.id);
          // Never an out-of-window seasonal question.
          const selectable = [...inWindow, ...evergreen];
          expect(selectable.some((question) => question.id === picked.id)).toBe(true);
          const seen = new Set(history);
          const firstUnseenSeasonal = inWindow.find((question) => !seen.has(question.id));
          const firstUnseenEvergreen = evergreen.find((question) => !seen.has(question.id));
          if (firstUnseenSeasonal !== undefined) {
            // An unseen in-window seasonal question always wins.
            expect(picked.id).toBe(firstUnseenSeasonal.id);
          } else if (firstUnseenEvergreen !== undefined) {
            expect(picked.id).toBe(firstUnseenEvergreen.id);
          }
        },
      ),
    );
  });
});
