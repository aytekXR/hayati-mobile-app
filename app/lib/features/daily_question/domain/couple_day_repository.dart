import 'couple_day_assignment.dart';

/// Read seam for `couples/{cid}/days/{yyyymmdd}` (M3.3,
/// docs/architecture.md §3). Watch-only by construction — the day doc is
/// function-only (every client write rules-denied); a missing doc is the
/// honest no-day-yet state (pre-first-rollover, deploy lag, or the ≤1h
/// window after the couple's local midnight before the hourly sweep runs).
abstract interface class CoupleDayRepository {
  /// Live day assignment (null while the rollover has not assigned one).
  Stream<CoupleDayAssignment?> watchDay(String coupleId, String dayKey);
}
