import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/coach/domain/coach_exception.dart';

void main() {
  const noPayloadMembers = <CoachException>[
    CoachNotMemberException(),
    CoachNotPremiumException(),
    CoachDailyCapException(),
    CoachMonthlyCapException(),
    CoachRateLimitedException(),
    CoachLimitReachedException(),
    CoachUnavailableException(),
  ];

  group('no-payload members — value semantics', () {
    test('a fresh instance equals a const instance (not identity)', () {
      // ignore: prefer_const_constructors
      final fresh = CoachDailyCapException();
      expect(fresh, equals(const CoachDailyCapException()));
      expect(fresh.hashCode, const CoachDailyCapException().hashCode);
    });

    test('distinct member types are never equal', () {
      expect(
        const CoachNotMemberException(),
        isNot(equals(const CoachDailyCapException())),
      );
      expect(
        const CoachDailyCapException(),
        isNot(equals(const CoachMonthlyCapException())),
      );
    });
  });

  group('no-content rule — no-payload members carry no message', () {
    test('toString is just the class name, with no message field', () {
      for (final member in noPayloadMembers) {
        expect(member.toString(), endsWith('()'));
        expect(member.toString(), isNot(contains('message')));
      }
    });
  });

  group('CoachUnknownException — the only member with a payload', () {
    test('value semantics over code + message', () {
      const a = CoachUnknownException(code: 'internal', message: 'boom');
      const b = CoachUnknownException(code: 'internal', message: 'boom');
      const c = CoachUnknownException(code: 'other', message: 'boom');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString exposes only the (static, server-originated) code + message', () {
      const failure = CoachUnknownException(code: 'internal', message: 'boom');
      expect(failure.toString(), contains('code: internal'));
      expect(failure.toString(), contains('message: boom'));
    });

    test('message may be null (a dropped/absent server message)', () {
      const failure = CoachUnknownException(code: 'malformed-response');
      expect(failure.message, isNull);
      expect(failure.toString(), contains('message: null'));
    });
  });
}
