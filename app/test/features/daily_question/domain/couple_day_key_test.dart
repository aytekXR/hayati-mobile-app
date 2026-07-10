import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day.dart';
import 'package:timezone/timezone.dart' as tz;

/// M3.3 dayKey parity (ADR-011): the Dart mirror must agree byte-for-byte
/// with the functions `localDayKey` for shared instants/zones — both sides
/// pin the SAME fixture (functions/test/fixtures/day-key-parity.json, TS
/// side: day-key-parity.test.ts). A mismatch is tzdata skew or a broken
/// mirror; both are release-blocking. Plain test() + dart:io like the
/// shipped-pack loaders: flutter test runs with CWD = app/.
File _parityFixture() {
  // CWD is app/ under `flutter test` (CI and local); walk up as insurance
  // against a root-level runner.
  var dir = Directory.current;
  for (var depth = 0; depth < 4; depth++) {
    final candidate = File(
      '${dir.path}/functions/test/fixtures/day-key-parity.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail(
    'day-key-parity.json not found walking up from ${Directory.current.path} '
    '— the shared fixture lives at functions/test/fixtures/.',
  );
}

void main() {
  final fixture =
      jsonDecode(_parityFixture().readAsStringSync()) as Map<String, dynamic>;
  final cases = (fixture['cases'] as List<dynamic>).cast<Map<String, dynamic>>();

  group('coupleDayKey ↔ localDayKey parity fixture (Dart side)', () {
    test('carries a usable spread: boundaries, DST shifts, sub-hour offsets',
        () {
      expect(cases.length, greaterThanOrEqualTo(15));
      final zones = cases.map((c) => c['zone']).toSet();
      expect(
        zones,
        containsAll([
          'Europe/Istanbul',
          'America/New_York',
          'Europe/London',
          'Asia/Kathmandu',
          'Pacific/Chatham',
        ]),
      );
    });

    for (final parityCase in cases) {
      final instant = parityCase['instant'] as String;
      final zone = parityCase['zone'] as String;
      final dayKey = parityCase['dayKey'] as String;
      test('$instant @ $zone → $dayKey', () {
        expect(
          coupleDayKey(DateTime.parse(instant), zone),
          dayKey,
          reason: 'parity mismatch for $instant @ $zone — '
              'tzdata skew (package:timezone vs Node ICU) or a broken mirror',
        );
      });
    }
  });

  group('coupleDayKey', () {
    test('a local-representation DateTime keys the same instant', () {
      // TZDateTime.from converts via the epoch, so the DateTime's own zone
      // representation must not matter — only the instant it names.
      final utc = DateTime.utc(2026, 7, 9, 21);
      expect(
        coupleDayKey(utc.toLocal(), 'Europe/Istanbul'),
        coupleDayKey(utc, 'Europe/Istanbul'),
      );
    });

    test('throws on a timezone id outside the bundled IANA set', () {
      // Couple timezones are allow-listed at join and rules-frozen (M3.3);
      // an unknown id is corrupt state — loud, never a guessed date or a
      // device-zone fallback (ADR-011).
      expect(
        () => coupleDayKey(DateTime.utc(2026, 7, 9, 12), 'Not/AZone'),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
    });

    test('hourly steps across the London fall-back day never rewind or skip',
        () {
      // Mini-sweep mirroring the TS fast-check property on the hardest day:
      // the 25-hour 2026-10-25 (Europe/London). Keys must be monotonically
      // non-decreasing and step by exactly one calendar day.
      var previous = coupleDayKey(DateTime.utc(2026, 10, 24, 20), 'Europe/London');
      for (var hour = 21; hour <= 52; hour++) {
        final key = coupleDayKey(
          DateTime.utc(2026, 10, 24, 20).add(Duration(hours: hour - 20)),
          'Europe/London',
        );
        expect(key.compareTo(previous), greaterThanOrEqualTo(0));
        if (key != previous) {
          DateTime toDate(String k) => DateTime.utc(
                int.parse(k.substring(0, 4)),
                int.parse(k.substring(4, 6)),
                int.parse(k.substring(6, 8)),
              );
          expect(toDate(key).difference(toDate(previous)).inDays, 1);
        }
        previous = key;
      }
    });

    test('ensureCoupleTimeZonesInitialized is idempotent', () {
      ensureCoupleTimeZonesInitialized();
      ensureCoupleTimeZonesInitialized();
      expect(
        coupleDayKey(DateTime.utc(2026, 1, 5, 9), 'Europe/Istanbul'),
        '20260105',
      );
    });
  });
}
