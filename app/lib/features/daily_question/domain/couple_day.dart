import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The couple's dayKey (M3.3, ADR-011 binding contract).
///
/// `couples/{cid}/days/{yyyymmdd}` ids are the couple's LOCAL calendar date
/// in the couple's STORED `timezone` — a pure function of that zone, NEVER
/// the device zone: a couple stored as Europe/Istanbul with a device in
/// another zone would otherwise read the wrong day doc around midnight.
/// This is the Dart mirror of the rollover's `localDayKey`
/// (functions/src/rollover/day-key.ts); the two are pinned byte-for-byte by
/// the shared fixture functions/test/fixtures/day-key-parity.json, consumed
/// on this side by couple_day_key_test.dart. The zone database is
/// package:timezone's 10-year window (latest_10y): the app only ever keys
/// "now", so historical rules are dead weight — and the fixture's
/// rule-stable-zones policy keeps tzdata skew against Node's ICU out of the
/// equation.

bool _timeZonesInitialized = false;

/// Idempotent timezone-database init. Wired into the app entrypoints before
/// `runHayati` and called lazily by [coupleDayKey] as a safety net, so a
/// missed bootstrap can never surface as a spurious LocationNotFoundException.
void ensureCoupleTimeZonesInitialized() {
  if (_timeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _timeZonesInitialized = true;
}

/// The `yyyymmdd` key of [instant]'s calendar date in [timeZone].
///
/// [instant] is a point in time — local or UTC representation both work
/// (`TZDateTime.from` converts via the epoch). An unknown [timeZone] throws
/// [tz.LocationNotFoundException]: couple timezones are allow-listed at join
/// and rules-frozen since M3.3, so an unknown id here is corrupt state —
/// surface it loudly (the day-key provider maps it to an honest error
/// state), never guess a date or fall back to the device zone.
String coupleDayKey(DateTime instant, String timeZone) {
  ensureCoupleTimeZonesInitialized();
  final local = tz.TZDateTime.from(instant, tz.getLocation(timeZone));
  return '${local.year.toString().padLeft(4, '0')}'
      '${local.month.toString().padLeft(2, '0')}'
      '${local.day.toString().padLeft(2, '0')}';
}
