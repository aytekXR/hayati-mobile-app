// M3.4 couple streak engine (ADR-012 Decision 2, docs/architecture.md §3,
// docs/prd.md F3). PURE calendar math over dayKeys: a dayKey is the couple's
// LOCAL calendar date as yyyymmdd (produced upstream by localDayKey(instant,
// couples.timezone) — day-key.ts / ADR-011). Once keys exist the streak is
// zone-free by construction: no Date, no offset, no DST ever enters this
// module — only 8-digit Gregorian dates compared and stepped. That is what
// lets every PRD streak property (grace, gaps, DST/zone edges) be tested
// without an emulator. The trigger (handleAnswerCreated) is the ONLY writer
// of couples.streak; it feeds parseStreak → applyMutualDay → back to the doc
// inside one transaction, so this file owns the semantics and nothing else does.

/**
 * The couples.streak field. `lastMutualDate` is the yyyymmdd dayKey of the most
 * recent mutual day (both partners answered), or null before the first ever.
 * `graceTokens` is the weekly "mercy day" budget (PRD F3): at most one 1-day
 * gap can be bridged per ISO week; the token refills on entry to a later week.
 * Shape pinned by architecture.md §3 at M3.2 — do NOT add fields without also
 * updating parseStreak (which rejects unknown keys as corrupt) in lockstep.
 */
export interface StreakState {
  count: number;
  lastMutualDate: string | null;
  graceTokens: number;
}

/**
 * The zero state an ABSENT streak field reads as (ADR-012 D2): no mutual day
 * yet, one grace token in hand. Chosen so the join Function needs no migration
 * and no streak write — the field simply does not exist until the first mutual
 * day, and both this constant and the rules' symmetric absence handling agree
 * on what "not there yet" means.
 */
export const INITIAL_STREAK: StreakState = {
  count: 0,
  lastMutualDate: null,
  graceTokens: 1,
};

/** parseStreak's result: the usable state plus whether the wire was corrupt. */
export interface ParsedStreak {
  readonly state: StreakState;
  /**
   * True iff `raw` was PRESENT but malformed (wrong types, negative/non-integer
   * numbers, a bad dayKey string, or unknown keys). An absent field is the
   * expected zero state, NOT corruption, so this is false for undefined.
   */
  readonly corrupt: boolean;
}

const DAY_MS = 86_400_000;
const DAY_KEY_PATTERN = /^\d{8}$/;

/**
 * Validates a yyyymmdd dayKey and returns its numeric parts. Rejects anything
 * that is not exactly 8 ASCII digits of a REAL Gregorian date: month 00/13,
 * day 00/32, Feb 30, and the JS two-digit-year trap (Date.UTC maps years 0–99
 * to 1900–1999) are all caught by the round-trip check. Throws loudly naming
 * the input — a malformed dayKey here is corrupt server state (the day-doc id),
 * never something to guess around (mirrors day-key.ts's posture on bad zones).
 */
function dayKeyParts(dayKey: string): { year: number; month: number; day: number } {
  if (!DAY_KEY_PATTERN.test(dayKey)) {
    throw new Error(`invalid dayKey '${dayKey}': expected 8 digits yyyymmdd`);
  }
  const year = Number(dayKey.slice(0, 4));
  const month = Number(dayKey.slice(4, 6));
  const day = Number(dayKey.slice(6, 8));
  const utc = new Date(Date.UTC(year, month - 1, day));
  if (
    utc.getUTCFullYear() !== year ||
    utc.getUTCMonth() !== month - 1 ||
    utc.getUTCDate() !== day
  ) {
    throw new Error(`invalid dayKey '${dayKey}': not a real calendar date`);
  }
  return { year, month, day };
}

/** yyyymmdd of a Date's UTC calendar fields (zero-padded; UTC only — no zone). */
function formatUtcDayKey(date: Date): string {
  const year = String(date.getUTCFullYear()).padStart(4, '0');
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}${month}${day}`;
}

/**
 * `dayKey` shifted by `n` calendar days (n may be negative). Pure Gregorian
 * math via Date.UTC — the arithmetic runs in UTC purely to borrow the calendar
 * (leap years, month lengths, year rollover), never as a timezone: the day is
 * already zone-projected. Throws on a malformed dayKey or non-integer n.
 */
export function addDaysToDayKey(dayKey: string, n: number): string {
  if (!Number.isInteger(n)) {
    throw new Error(`addDaysToDayKey: n must be an integer, got ${n}`);
  }
  const { year, month, day } = dayKeyParts(dayKey);
  return formatUtcDayKey(new Date(Date.UTC(year, month - 1, day + n)));
}

/**
 * The ISO-8601 week key of `dayKey` as "YYYY-Www" (Monday-start weeks). YYYY is
 * the ISO week-NUMBERING year, which diverges from the calendar year at the
 * year boundary: e.g. isoWeekKey('20270101') === '2026-W53' (2027-01-01 is a
 * Friday, still in 2026's last week). The key is built so lexicographic compare
 * equals chronological week order (4-digit year, zero-padded 2-digit week),
 * which is exactly what applyMutualDay's refill test relies on. Standard
 * Thursday-anchored algorithm (the ISO week-year is the year of this week's
 * Thursday). Throws on a malformed dayKey.
 */
export function isoWeekKey(dayKey: string): string {
  const { year, month, day } = dayKeyParts(dayKey);
  const date = new Date(Date.UTC(year, month - 1, day));
  // getUTCDay: Sun=0..Sat=6 → ISO Mon=1..Sun=7.
  const isoWeekday = date.getUTCDay() || 7;
  // Step to this ISO week's Thursday; its calendar year IS the ISO week-year.
  date.setUTCDate(date.getUTCDate() + 4 - isoWeekday);
  const isoYear = date.getUTCFullYear();
  const yearStart = Date.UTC(isoYear, 0, 1);
  const week = Math.ceil((date.getTime() - yearStart) / DAY_MS / 7 + 1 / 7);
  return `${String(isoYear).padStart(4, '0')}-W${String(week).padStart(2, '0')}`;
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0;
}

const STREAK_FIELDS = new Set(['count', 'lastMutualDate', 'graceTokens']);

/**
 * Defensive wire parser for couples.streak, returning {state, corrupt} so the
 * CALLER (the trigger) can log the corruption loudly while this function stays
 * pure. Policy:
 *   - undefined / absent   → INITIAL_STREAK, corrupt: false (the expected
 *     "no mutual day yet" state; the field does not exist until the first).
 *   - a structurally valid object → its values, corrupt: false. Valid means
 *     EXACTLY the keys {count, lastMutualDate, graceTokens}; count and
 *     graceTokens non-negative integers; lastMutualDate null or a real yyyymmdd
 *     dayKey. Validation is structural (types + ranges + real date), NOT
 *     cross-field — a semantically odd but well-typed state is passed through.
 *     graceTokens > 1 is accepted (the engine is robust to any budget), so a
 *     future multi-token policy is not misread as corruption.
 *   - anything else (wrong type, negative/non-integer number, bad dayKey
 *     string, unknown key) → INITIAL_STREAK, corrupt: true. The field is
 *     admin-SDK-owned (rules freeze it against clients), so a malformed shape
 *     means a bug or a manual poke — surfaced, never trusted.
 * parseStreak below is the pure StreakState-returning form for callers that do
 * not need the flag.
 */
export function parseStreakChecked(raw: unknown): ParsedStreak {
  if (raw === undefined) {
    return { state: INITIAL_STREAK, corrupt: false };
  }
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return { state: INITIAL_STREAK, corrupt: true };
  }
  const record = raw as Record<string, unknown>;
  for (const key of Object.keys(record)) {
    if (!STREAK_FIELDS.has(key)) {
      return { state: INITIAL_STREAK, corrupt: true };
    }
  }
  const { count, lastMutualDate, graceTokens } = record;
  if (!isNonNegativeInteger(count) || !isNonNegativeInteger(graceTokens)) {
    return { state: INITIAL_STREAK, corrupt: true };
  }
  if (lastMutualDate !== null) {
    if (typeof lastMutualDate !== 'string') {
      return { state: INITIAL_STREAK, corrupt: true };
    }
    try {
      dayKeyParts(lastMutualDate);
    } catch {
      return { state: INITIAL_STREAK, corrupt: true };
    }
  }
  return { state: { count, lastMutualDate, graceTokens }, corrupt: false };
}

/**
 * Pure StreakState form of parseStreakChecked (the verbatim `raw → StreakState`
 * contract). Use parseStreakChecked when you need to log corruption loudly.
 */
export function parseStreak(raw: unknown): StreakState {
  return parseStreakChecked(raw).state;
}

/**
 * Fold one mutual day into the streak (ADR-012 Decision 2). Pure and total over
 * a valid dayKey; the couple-local calendar means every decision is a compare
 * or a day-step between yyyymmdd keys. Order is load-bearing:
 *
 *   0. First mutual day ever (lastMutualDate == null) → count = 1; graceTokens
 *      preserved (INITIAL carries 1). No prior week exists to refill against.
 *   1. dayKey <= lastMutualDate → state UNCHANGED. Same-day is idempotence
 *      (defense in depth behind the trigger's reveal latch); an older dayKey is
 *      a late completion that still stamps that day's revealedAt but never
 *      rewrites streak history. Neither can have advanced the ISO week (dayKey
 *      is not later), so skipping the refill here is correct, not a shortcut.
 *   2. REFILL FIRST (dayKey > lastMutualDate): entering a strictly later ISO
 *      week restores graceTokens to 1 BEFORE this day can spend it — one bridge
 *      per ISO week, restored on week entry. isoWeekKey compares lexically =
 *      chronologically, so the year-boundary week-year (2027-01-01 ∈ 2026-W53)
 *      is handled with no special case.
 *   3. Consecutive (dayKey == last + 1) → count + 1 (graceTokens = refilled).
 *   4. Exactly one missed day (dayKey == last + 2) AND a token in hand
 *      post-refill → BRIDGE: count + 1, graceTokens - 1.
 *   5. Otherwise (gap of ≥2 missed days, or one missed with no token) → RESET:
 *      count = 1. The reset consumes nothing, so graceTokens keeps its
 *      (possibly refilled) value.
 *
 * lastMutualDate only ever moves forward — it becomes dayKey exactly when
 * dayKey > lastMutualDate, and is left untouched otherwise.
 */
export function applyMutualDay(prev: StreakState, dayKey: string): StreakState {
  // Validate up front so a malformed dayKey is loud even on the unchanged paths
  // below (which otherwise never call the throwing calendar helpers).
  dayKeyParts(dayKey);

  const last = prev.lastMutualDate;
  if (last === null) {
    return { count: 1, lastMutualDate: dayKey, graceTokens: prev.graceTokens };
  }
  if (dayKey <= last) {
    return prev;
  }

  const graceTokens = isoWeekKey(dayKey) > isoWeekKey(last) ? 1 : prev.graceTokens;

  if (dayKey === addDaysToDayKey(last, 1)) {
    return { count: prev.count + 1, lastMutualDate: dayKey, graceTokens };
  }
  if (dayKey === addDaysToDayKey(last, 2) && graceTokens >= 1) {
    return { count: prev.count + 1, lastMutualDate: dayKey, graceTokens: graceTokens - 1 };
  }
  return { count: 1, lastMutualDate: dayKey, graceTokens };
}
