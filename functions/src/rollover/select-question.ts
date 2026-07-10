// Deterministic day-question selection (ADR-011 decision 4). Pure function of
// (pack, days-history): the caller reads the couple's days subcollection and
// passes the assigned questionIds; same inputs always produce the same
// question, which is what lets the client prefetch offline and makes
// concurrent rollover runs race benignly (they compute identical
// assignments). Policy, in order:
//   1. seasonalWindow questions are excluded entirely — the documented
//      evergreen-only deferral (no shipped question carries a window yet;
//      the Hijri window->date mapping lands with the first seasonal content).
//   2. First UNSEEN evergreen question in pack authoring order (the
//      curriculum order the solo week established).
//   3. Pack exhausted: recycle by minimum times-assigned, pack order breaking
//      ties — deterministic round-robin, starvation-free.
// Register is a pack-level property (the pack IS the register choice), so
// "register honored" holds by construction: the result is always a member of
// the configured pack.
import type { Question, QuestionPack } from './pack-loader';

/** Every question in the pack is seasonal — nothing is selectable under the evergreen-only policy. */
export class NoSelectableQuestionError extends Error {
  constructor(packId: string) {
    super(`pack '${packId}' has no evergreen question to select`);
    this.name = 'NoSelectableQuestionError';
  }
}

/**
 * Picks the day's question for a couple. `historyQuestionIds` is one entry
 * per existing day doc (duplicates accumulate once recycling has begun);
 * ids that are no longer in the pack (removed by a version bump) are ignored.
 */
export function selectQuestion(
  pack: QuestionPack,
  historyQuestionIds: readonly string[],
): Question {
  const evergreen = pack.questions.filter((question) => question.seasonalWindow === undefined);
  if (evergreen.length === 0) {
    throw new NoSelectableQuestionError(pack.packId);
  }
  const counts = new Map<string, number>();
  for (const id of historyQuestionIds) {
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  // Single pass keeps the earliest pack-order question on count ties (strict <).
  let picked = evergreen[0];
  let pickedCount = counts.get(picked.id) ?? 0;
  for (const candidate of evergreen.slice(1)) {
    const count = counts.get(candidate.id) ?? 0;
    if (count < pickedCount) {
      picked = candidate;
      pickedCount = count;
    }
  }
  return picked;
}
