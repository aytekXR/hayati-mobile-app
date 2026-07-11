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

    test('streak defaults to the zero state (a brand-new couple)', () {
      // An unspecified streak is the same read model as an absent wire field:
      // count 0, no last mutual day, one mercy token (ADR-012).
      expect(couple.streak, CoupleStreak.zero);
    });

    test('streak is part of identity (server truth, not incidental)', () {
      // Two couples that differ ONLY in their streak are different read models
      // — a live streak update must re-emit as a not-equal Couple so the home
      // rebuilds. hashCode moves with it.
      const withStreak = Couple(
        id: 'couple_1',
        memberUids: ['uid_creator', 'uid_joiner'],
        timezone: 'Europe/Istanbul',
        streak: CoupleStreak(
          count: 4,
          lastMutualDate: '20260709',
          graceTokens: 1,
        ),
      );

      expect(couple, isNot(withStreak));
      expect(couple.hashCode, isNot(withStreak.hashCode));
    });
  });

  group('CoupleStreak', () {
    test('zero mirrors the Functions INITIAL_STREAK', () {
      // count 0 / lastMutualDate null / graceTokens 1 — the two sides can never
      // disagree on "brand-new couple" (ADR-012 Decision 2).
      expect(CoupleStreak.zero.count, 0);
      expect(CoupleStreak.zero.lastMutualDate, isNull);
      expect(CoupleStreak.zero.graceTokens, 1);
    });

    test('value equality is field-based', () {
      const streak = CoupleStreak(
        count: 4,
        lastMutualDate: '20260709',
        graceTokens: 1,
      );

      expect(
        streak,
        const CoupleStreak(
          count: 4,
          lastMutualDate: '20260709',
          graceTokens: 1,
        ),
      );
      expect(
        streak.hashCode,
        const CoupleStreak(
          count: 4,
          lastMutualDate: '20260709',
          graceTokens: 1,
        ).hashCode,
      );
      // Each field participates in identity.
      expect(
        streak,
        isNot(
          const CoupleStreak(
            count: 5,
            lastMutualDate: '20260709',
            graceTokens: 1,
          ),
        ),
      );
      expect(
        streak,
        isNot(
          const CoupleStreak(
            count: 4,
            lastMutualDate: '20260710',
            graceTokens: 1,
          ),
        ),
      );
      expect(
        streak,
        isNot(
          const CoupleStreak(
            count: 4,
            lastMutualDate: '20260709',
            graceTokens: 0,
          ),
        ),
      );
    });

    test('toString names every field for diagnostics', () {
      const streak = CoupleStreak(
        count: 4,
        lastMutualDate: '20260709',
        graceTokens: 1,
      );

      expect(streak.toString(), contains('4'));
      expect(streak.toString(), contains('20260709'));
      expect(streak.toString(), contains('graceTokens: 1'));
    });
  });
}
