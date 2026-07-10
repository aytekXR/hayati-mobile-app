import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';

void main() {
  group('Couple', () {
    const couple = Couple(
      id: 'couple_1',
      memberUids: ['uid_creator', 'uid_joiner'],
      timezone: 'Europe/Istanbul',
    );

    test('partnerUidFor returns the other member, from either side', () {
      expect(couple.partnerUidFor('uid_creator'), 'uid_joiner');
      expect(couple.partnerUidFor('uid_joiner'), 'uid_creator');
    });

    test('partnerUidFor returns null for a non-member uid (never guesses)', () {
      // A users.coupleId pointing at a foreign couple is corrupt state;
      // callers surface it as an error rather than pick an arbitrary member.
      expect(couple.partnerUidFor('uid_stranger'), isNull);
    });

    test('value equality is field-based', () {
      expect(
        couple,
        const Couple(
          id: 'couple_1',
          memberUids: ['uid_creator', 'uid_joiner'],
          timezone: 'Europe/Istanbul',
        ),
      );
      expect(
        couple.hashCode,
        const Couple(
          id: 'couple_1',
          memberUids: ['uid_creator', 'uid_joiner'],
          timezone: 'Europe/Istanbul',
        ).hashCode,
      );
      expect(
        couple,
        isNot(
          const Couple(
            id: 'couple_2',
            memberUids: ['uid_creator', 'uid_joiner'],
            timezone: 'Europe/Istanbul',
          ),
        ),
      );
    });

    test('memberUids order is part of identity (creator-first is a wire '
        'contract)', () {
      // Slot 0 is the creator by the M2.3 contract, so a reordered list names
      // a different couple — equality must be order-sensitive, never a set.
      const reordered = Couple(
        id: 'couple_1',
        memberUids: ['uid_joiner', 'uid_creator'],
        timezone: 'Europe/Istanbul',
      );

      expect(couple, isNot(reordered));
    });

    test('toString names the id and timezone for diagnostics', () {
      expect(couple.toString(), contains('couple_1'));
      expect(couple.toString(), contains('Europe/Istanbul'));
    });
  });
}
