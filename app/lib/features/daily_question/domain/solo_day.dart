import 'question.dart';

/// Pure day arithmetic for the solo week (M2.4, docs/architecture.md §3/§4).
///
/// The anchor is the rules-enforced, create-once `users/{uid}.createdAt`
/// server stamp, read through `RelationshipProfile.createdAt`. Day N is a
/// LOCAL CALENDAR distance, not a count of 24-hour intervals: an account
/// created at 23:59 sees day 2 two minutes later. Every function here reads
/// only the DATE COMPONENTS (year/month/day) of the wall-clock values it is
/// given — hour arithmetic never happens, so DST transitions (23/25-hour
/// days) cannot shift a boundary and the math is deterministic on any host
/// timezone. Callers pass local wall-clock `DateTime`s (`.toLocal()` the
/// anchor; `soloClockProvider` for now).

/// The solo cycle length (docs/mvp.md IN #2, docs/prd.md F1: "7 days of solo
/// reflection questions"). Also the exact question count every solo pack
/// must carry (enforced at asset load).
const int soloQuestionDays = 7;

/// 1-based solo day: 1 on the anchor's calendar date, 2 the next date, …
///
/// Null [anchor] (the pending-serverTimestamp window right after the first
/// profile save) and a future anchor (clock skew between the server stamp and
/// the device clock) both clamp to day 1 — the honest floor, never a crash
/// or a negative day.
int soloDayNumber({required DateTime? anchor, required DateTime now}) {
  if (anchor == null) return 1;
  final elapsedDays = _daysSinceEpoch(now) - _daysSinceEpoch(anchor);
  if (elapsedDays < 0) return 1;
  return elapsedDays + 1;
}

/// True once the 7-question cycle is exhausted (day 8+): the rotation stops
/// — questions never repeat — and the invite nudge becomes the primary CTA
/// (decision documented in docs/adr/009).
bool soloCycleComplete(int dayNumber) => dayNumber > soloQuestionDays;

/// The `users/{uid}/soloAnswers/{yyyymmdd}` document id for [now]'s local
/// calendar date — one answer bucket per day, same `yyyymmdd` shape as the
/// couple's `days/{yyyymmdd}` (docs/architecture.md §3).
String soloDayKey(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}'
    '${now.month.toString().padLeft(2, '0')}'
    '${now.day.toString().padLeft(2, '0')}';

/// Deterministic day→question selection: day 1 → `questions[0]` … day
/// [soloQuestionDays] → `questions[6]`; anything outside the cycle → null
/// (the completed state owns day 8+). Assumes the pack passed the load-time
/// exactly-7 check.
Question? soloQuestionForDay(QuestionPack pack, int dayNumber) {
  if (dayNumber < 1 || dayNumber > soloQuestionDays) return null;
  return pack.questions[dayNumber - 1];
}

/// Calendar-date ordinal via a UTC reconstruction of the date components:
/// immune to DST because the reconstructed instants are exact multiples of
/// 24h apart regardless of what the local zone did that day.
int _daysSinceEpoch(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).difference(DateTime.utc(1970)).inDays;
