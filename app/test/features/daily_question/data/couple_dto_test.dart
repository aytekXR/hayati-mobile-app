import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/couple_dto.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';

/// A wire-shaped `couples/{coupleId}` document; tests mutate copies of it to
/// hit each loud branch (same idiom as question_pack_dto_test — the doc id is
/// externally known, so it is passed in, never carried in the map).
Map<String, dynamic> validCouple() => {
  'memberUids': ['uid_creator', 'uid_joiner'],
  'timezone': 'Europe/Istanbul',
};

void main() {
  group('coupleFromMap', () {
    test('maps a wire document into the domain, creator-first', () {
      final couple = coupleFromMap('couple_1', validCouple());

      expect(couple.id, 'couple_1');
      expect(couple.memberUids, ['uid_creator', 'uid_joiner']);
      expect(couple.timezone, 'Europe/Istanbul');
    });

    test('rejects a non-list memberUids loudly', () {
      expect(
        () => coupleFromMap('couple_1', validCouple()..['memberUids'] = 'nope'),
        throwsFormatException,
      );
    });

    test('rejects a memberUids that is not exactly two entries loudly', () {
      // The M2.3 join contract is exactly two members; a solo or a trio is
      // corrupt state, never silently tolerated.
      expect(
        () =>
            coupleFromMap('couple_1', validCouple()..['memberUids'] = ['solo']),
        throwsFormatException,
      );
      expect(
        () => coupleFromMap(
          'couple_1',
          validCouple()..['memberUids'] = ['a', 'b', 'c'],
        ),
        throwsFormatException,
      );
    });

    test('rejects a non-string or empty member uid loudly', () {
      expect(
        () => coupleFromMap(
          'couple_1',
          validCouple()..['memberUids'] = ['uid_creator', 42],
        ),
        throwsFormatException,
      );
      expect(
        () => coupleFromMap(
          'couple_1',
          validCouple()..['memberUids'] = ['uid_creator', ''],
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing, empty or non-string timezone loudly', () {
      // timezone is the sole input to coupleDayKey (ADR-011); a blank or
      // wrong-typed zone must fail here, never fall back to the device zone.
      expect(
        () => coupleFromMap('couple_1', validCouple()..remove('timezone')),
        throwsFormatException,
      );
      expect(
        () => coupleFromMap('couple_1', validCouple()..['timezone'] = ''),
        throwsFormatException,
      );
      expect(
        () => coupleFromMap('couple_1', validCouple()..['timezone'] = 42),
        throwsFormatException,
      );
    });
  });

  group('coupleFromMap streak (M3.4, ADR-012)', () {
    test('an absent streak field reads as the zero state', () {
      // The field does not exist until the couple's first mutual day — a
      // brand-new couple is honestly the zero streak, never an error.
      final couple = coupleFromMap('couple_1', validCouple());

      expect(couple.streak, CoupleStreak.zero);
    });

    test('maps a present streak submap into the domain', () {
      final couple = coupleFromMap('couple_1', {
        ...validCouple(),
        'streak': {
          'count': 4,
          'lastMutualDate': '20260709',
          'graceTokens': 1,
        },
      });

      expect(
        couple.streak,
        const CoupleStreak(
          count: 4,
          lastMutualDate: '20260709',
          graceTokens: 1,
        ),
      );
    });

    test('rejects a non-map streak loudly', () {
      expect(
        () =>
            coupleFromMap('couple_1', {...validCouple(), 'streak': 'nope'}),
        throwsFormatException,
      );
    });

    test('rejects a missing, non-int or negative count loudly', () {
      for (final bad in <Object?>[null, '4', 4.5, -1]) {
        expect(
          () => coupleFromMap('couple_1', {
            ...validCouple(),
            'streak': {
              'count': bad,
              'lastMutualDate': '20260709',
              'graceTokens': 1,
            },
          }),
          throwsFormatException,
          reason: 'count=$bad must fail loudly',
        );
      }
    });

    test('rejects a missing, non-int or negative graceTokens loudly', () {
      for (final bad in <Object?>[null, '1', 1.5, -1]) {
        expect(
          () => coupleFromMap('couple_1', {
            ...validCouple(),
            'streak': {
              'count': 4,
              'lastMutualDate': '20260709',
              'graceTokens': bad,
            },
          }),
          throwsFormatException,
          reason: 'graceTokens=$bad must fail loudly',
        );
      }
    });

    test('rejects a present submap missing/blank lastMutualDate loudly', () {
      // The reveal trigger writes all three fields atomically (ADR-012
      // Decision 1), so a positive-streak record with no last date is corrupt
      // state — we throw rather than fabricate a null date that would drift the
      // server-side arithmetic. Absent (null) is the ONLY path to a null date.
      for (final bad in <Object?>[null, '', 20260709]) {
        expect(
          () => coupleFromMap('couple_1', {
            ...validCouple(),
            'streak': {
              'count': 4,
              'lastMutualDate': bad,
              'graceTokens': 1,
            },
          }),
          throwsFormatException,
          reason: 'lastMutualDate=$bad must fail loudly',
        );
      }
    });
  });
}
