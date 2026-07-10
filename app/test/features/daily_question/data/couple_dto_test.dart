import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/couple_dto.dart';

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
}
