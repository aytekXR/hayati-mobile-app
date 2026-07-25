// Deterministic day-question selection (ADR-011 decision 4, as amended by
// ADR-026 D4). Pure function of (pack, days-history, dayKey): the caller reads
// the couple's days subcollection and passes the assigned questionIds plus the
// dayKey of the doc it is about to create. Policy, in order:
//   1. In-window seasonal, UNSEEN — the first such question in pack authoring
//      order. "Unseen" is load-bearing: preferring seasonal questions ALWAYS
//      would loop a handful of Ramadan questions for thirty days while the
//      curriculum sat idle (ADR-026 D4).
//   2. Otherwise evergreen: first UNSEEN in pack authoring order (the
//      curriculum order the solo week established), then — once the pack is
//      exhausted — recycle by minimum times-assigned, pack order breaking
//      ties (deterministic round-robin, starvation-free).
//   3. Otherwise recycle the in-window seasonal set the same way; this is what
//      keeps an all-seasonal pack usable INSIDE its window.
//   4. Otherwise throw: nothing in this pack is selectable on this day.
// Seasonal questions whose window is CLOSED are excluded exactly as the old
// evergreen-only policy excluded every seasonal question.
//
// The window verdict comes from the dayKey — the id of the doc being written —
// never from the wall clock, so two overlapping sweeps assigning the same day
// doc agree on it (ADR-026 D1). Note the honest bound recorded there: the race
// is benign because create() is atomic and exactly one assignment can land;
// identical computation is what makes the discarded one uninteresting, and a
// history-read skew could already flip an evergreen pick before ADR-026.
//
// Register is a pack-level property (the pack IS the register choice), so
// "register honored" holds by construction: the result is always a member of
// the configured pack.
import type { Question, QuestionPack } from './pack-loader';
import { isSeasonalWindowOpen } from './seasonal-window';

/** Nothing in the pack is selectable on this day (an all-seasonal pack outside every window). */
export class NoSelectableQuestionError extends Error {
  constructor(packId: string, dayKey: string) {
    super(`pack '${packId}' has no question selectable on ${dayKey}`);
    this.name = 'NoSelectableQuestionError';
  }
}

/** Counts of each questionId in the history projection. */
function countsOf(historyQuestionIds: readonly string[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const id of historyQuestionIds) {
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  return counts;
}

/** Minimum times-assigned, earliest in pack order on ties (strict <). */
function leastAssigned(candidates: readonly Question[], counts: Map<string, number>): Question {
  let picked = candidates[0];
  let pickedCount = counts.get(picked.id) ?? 0;
  for (const candidate of candidates.slice(1)) {
    const count = counts.get(candidate.id) ?? 0;
    if (count < pickedCount) {
      picked = candidate;
      pickedCount = count;
    }
  }
  return picked;
}

/**
 * Picks the day's question for a couple. `historyQuestionIds` is one entry
 * per existing day doc (duplicates accumulate once recycling has begun);
 * ids that are no longer in the pack (removed by a version bump) are ignored.
 * `dayKey` is the `yyyymmdd` id of the day doc being assigned — the seasonal
 * window is resolved against it, never against `now`.
 */
export function selectQuestion(
  pack: QuestionPack,
  historyQuestionIds: readonly string[],
  dayKey: string,
): Question {
  const evergreen: Question[] = [];
  const inWindow: Question[] = [];
  for (const question of pack.questions) {
    if (question.seasonalWindow === undefined) {
      evergreen.push(question);
    } else if (isSeasonalWindowOpen(question.seasonalWindow, dayKey)) {
      inWindow.push(question);
    }
  }

  const counts = countsOf(historyQuestionIds);

  // 1. An unseen in-window seasonal question, in pack authoring order.
  const unseenSeasonal = inWindow.find((question) => !counts.has(question.id));
  if (unseenSeasonal !== undefined) {
    return unseenSeasonal;
  }
  // 2. The evergreen curriculum (unseen-first falls out of the min-count rule).
  if (evergreen.length > 0) {
    return leastAssigned(evergreen, counts);
  }
  // 3. An all-seasonal pack inside its window: recycle within the window.
  if (inWindow.length > 0) {
    return leastAssigned(inWindow, counts);
  }
  // 4. Nothing this pack offers is selectable today.
  throw new NoSelectableQuestionError(pack.packId, dayKey);
}
