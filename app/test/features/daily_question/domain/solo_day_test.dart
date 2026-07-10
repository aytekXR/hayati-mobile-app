import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/solo_day.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

void main() {
  test('the solo cycle is exactly the PRD F1 seven days', () {
    // docs/prd.md F1 / docs/mvp.md IN #2: "7 days of solo reflection
    // questions" — a different length is a product decision, so pin it.
    expect(soloQuestionDays, 7);
  });

  group('soloDayNumber', () {
    test('day 1 on the anchor\'s own calendar date, whatever the times', () {
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 7, 8, 0, 0, 1),
          now: DateTime(2026, 7, 8, 23, 59, 59),
        ),
        1,
      );
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 7, 8, 12),
          now: DateTime(2026, 7, 8, 12),
        ),
        1,
      );
    });

    test('the boundary is calendar midnight, not a 24h interval', () {
      // Two minutes of wall clock, but a new local date → day 2.
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 7, 8, 23, 59),
          now: DateTime(2026, 7, 9, 0, 1),
        ),
        2,
      );
      // 25 hours elapsed but only one date boundary crossed → still day 2.
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 7, 8, 0, 30),
          now: DateTime(2026, 7, 9, 1, 30),
        ),
        2,
      );
    });

    test('day 3 on the third calendar date even when <48h elapsed '
        '(the acceptance case)', () {
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 7, 8, 10),
          now: DateTime(2026, 7, 10, 9),
        ),
        3,
      );
    });

    test('day 7 closes the cycle; day 8 completes it', () {
      final anchor = DateTime(2026, 7, 1, 15);
      expect(soloDayNumber(anchor: anchor, now: DateTime(2026, 7, 7, 8)), 7);
      expect(soloCycleComplete(7), isFalse);
      expect(soloDayNumber(anchor: anchor, now: DateTime(2026, 7, 8, 8)), 8);
      expect(soloCycleComplete(8), isTrue);
      // The cycle never restarts: far future stays complete.
      expect(
        soloCycleComplete(
          soloDayNumber(anchor: anchor, now: DateTime(2027, 1, 1)),
        ),
        isTrue,
      );
    });

    test('a null anchor (pending server stamp) is day 1', () {
      expect(soloDayNumber(anchor: null, now: DateTime(2026, 7, 10)), 1);
    });

    test('a future anchor (clock skew) clamps to day 1, never negative', () {
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 7, 11, 0, 30),
          now: DateTime(2026, 7, 10, 23, 30),
        ),
        1,
      );
    });

    test('month, year and leap-day boundaries count as single days', () {
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 1, 31, 22),
          now: DateTime(2026, 2, 1, 2),
        ),
        2,
      );
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 12, 31, 23),
          now: DateTime(2027, 1, 1, 1),
        ),
        2,
      );
      // 2028 is a leap year: Feb 28 → Feb 29 → Mar 1.
      final leapAnchor = DateTime(2028, 2, 28, 12);
      expect(
        soloDayNumber(anchor: leapAnchor, now: DateTime(2028, 2, 29, 12)),
        2,
      );
      expect(
        soloDayNumber(anchor: leapAnchor, now: DateTime(2028, 3, 1, 12)),
        3,
      );
    });

    test('reads date components only — DST/offset changes cannot shift a '
        'boundary', () {
      // The contract: only year/month/day of the given wall-clock values
      // matter. UTC and local DateTimes with the same components agree, so a
      // zone's 23/25-hour DST day (same components, different real duration)
      // cannot change the result.
      expect(
        soloDayNumber(
          anchor: DateTime.utc(2026, 3, 29, 23, 30),
          now: DateTime.utc(2026, 3, 30, 0, 30),
        ),
        soloDayNumber(
          anchor: DateTime(2026, 3, 29, 23, 30),
          now: DateTime(2026, 3, 30, 0, 30),
        ),
      );
      // The EU spring-forward date itself: one date boundary → day 2,
      // although only 23 real hours elapse in such a zone.
      expect(
        soloDayNumber(
          anchor: DateTime(2026, 3, 28, 12),
          now: DateTime(2026, 3, 29, 12),
        ),
        2,
      );
    });
  });

  group('soloDayKey', () {
    test('formats the local calendar date as yyyymmdd', () {
      expect(soloDayKey(DateTime(2026, 7, 10, 23, 59)), '20260710');
    });

    test('zero-pads single-digit months and days', () {
      expect(soloDayKey(DateTime(2026, 1, 5)), '20260105');
    });

    test('agrees with soloDayNumber\'s date-component contract', () {
      // Same components, UTC vs local → same key.
      expect(
        soloDayKey(DateTime.utc(2026, 7, 10, 1)),
        soloDayKey(DateTime(2026, 7, 10, 1)),
      );
    });
  });

  group('soloQuestionForDay', () {
    final pack = SoloQuestionPack(
      packId: 'solo_en',
      version: 1,
      language: ContentLanguage.en,
      questions: [
        for (var day = 1; day <= soloQuestionDays; day++)
          SoloQuestion(
            id: 'solo_en_00$day',
            category: SoloQuestionCategory.deep,
            depth: 1,
            text: 'Question $day',
          ),
      ],
    );

    test('maps day 1 to the first question and day 7 to the last', () {
      expect(soloQuestionForDay(pack, 1)?.id, 'solo_en_001');
      expect(soloQuestionForDay(pack, 3)?.id, 'solo_en_003');
      expect(soloQuestionForDay(pack, 7)?.id, 'solo_en_007');
    });

    test('is deterministic — same day, same question', () {
      expect(soloQuestionForDay(pack, 4), soloQuestionForDay(pack, 4));
    });

    test('returns null outside the cycle (the completed state owns 8+)', () {
      expect(soloQuestionForDay(pack, 0), isNull);
      expect(soloQuestionForDay(pack, -1), isNull);
      expect(soloQuestionForDay(pack, 8), isNull);
    });
  });
}
