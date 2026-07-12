import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/coach/data/functions_coach_repository.dart';
import 'package:hayati_app/features/coach/domain/coach_exception.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';

// The plugin's FirebaseFunctionsException constructor is @protected; a subclass
// may still invoke it via super, which fabricates the real exception TYPE the
// boundary switches on without touching a live callable (the pairing mold).
class _FunctionsException extends FirebaseFunctionsException {
  _FunctionsException({
    required super.code,
    super.message = 'boom',
    super.details,
  });
}

/// Marker seeded through every failure path — no thrown exception's toString()
/// may ever contain it (ADR-017 Decision 5 no-content rule).
const _sentinel = 'HAYATI_APP_SENTINEL_9c2e';

void main() {
  group('coachReplyFromCallable — valid shapes', () {
    test('reply with a remaining hint', () {
      final reply = coachReplyFromCallable({
        'kind': 'reply',
        'text': 'hello there',
        'remaining': {'daily': 29, 'monthly': 999},
      });

      expect(reply.kind, CoachReplyKind.reply);
      expect(reply.text, 'hello there');
      expect(reply.category, isNull);
      expect(reply.remaining, const CoachRemaining(daily: 29, monthly: 999));
    });

    test('help with a category and no remaining (pre-scan shape)', () {
      final reply = coachReplyFromCallable({
        'kind': 'help',
        'text': 'please reach out',
        'category': 'selfHarm',
      });

      expect(reply.kind, CoachReplyKind.help);
      expect(reply.category, CoachCrisisCategory.selfHarm);
      expect(reply.remaining, isNull);
    });

    test('help with a category AND remaining (post-filter shape)', () {
      final reply = coachReplyFromCallable({
        'kind': 'help',
        'text': 'please reach out',
        'category': 'violence',
        'remaining': {'daily': 5, 'monthly': 100},
      });

      expect(reply.kind, CoachReplyKind.help);
      expect(reply.category, CoachCrisisCategory.violence);
      expect(reply.remaining, const CoachRemaining(daily: 5, monthly: 100));
    });

    test('an unknown category maps to null (display-only, never throws)', () {
      final reply = coachReplyFromCallable({
        'kind': 'reply',
        'text': 'x',
        'category': 'brand-new-category',
      });

      expect(reply.category, isNull);
    });

    test('remaining counts delivered as doubles decode to ints', () {
      final reply = coachReplyFromCallable({
        'kind': 'reply',
        'text': 'x',
        'remaining': {'daily': 29.0, 'monthly': 999.0},
      });

      expect(reply.remaining, const CoachRemaining(daily: 29, monthly: 999));
    });
  });

  group('coachReplyFromCallable — malformed shapes throw FormatException', () {
    test('non-map payloads', () {
      expect(() => coachReplyFromCallable('nope'), throwsFormatException);
      expect(() => coachReplyFromCallable(null), throwsFormatException);
      expect(() => coachReplyFromCallable(42), throwsFormatException);
    });

    test('bad or missing kind', () {
      expect(
        () => coachReplyFromCallable({'kind': 'nope', 'text': 'x'}),
        throwsFormatException,
      );
      expect(
        () => coachReplyFromCallable({'kind': 42, 'text': 'x'}),
        throwsFormatException,
      );
      expect(
        () => coachReplyFromCallable({'text': 'x'}),
        throwsFormatException,
      );
    });

    test('empty or non-string text', () {
      expect(
        () => coachReplyFromCallable({'kind': 'reply', 'text': ''}),
        throwsFormatException,
      );
      expect(
        () => coachReplyFromCallable({'kind': 'reply', 'text': 42}),
        throwsFormatException,
      );
      expect(
        () => coachReplyFromCallable({'kind': 'reply'}),
        throwsFormatException,
      );
    });

    test('malformed remaining shape', () {
      expect(
        () => coachReplyFromCallable({
          'kind': 'reply',
          'text': 'x',
          'remaining': 'nope',
        }),
        throwsFormatException,
      );
      expect(
        () => coachReplyFromCallable({
          'kind': 'reply',
          'text': 'x',
          'remaining': {'daily': 'a', 'monthly': 1},
        }),
        throwsFormatException,
      );
      expect(
        () => coachReplyFromCallable({
          'kind': 'reply',
          'text': 'x',
          'remaining': {'daily': 1},
        }),
        throwsFormatException,
      );
    });

    test('no malformed payload leaks its content into the FormatException', () {
      final malformed = <Object?>[
        _sentinel,
        {'kind': _sentinel, 'text': 'ok'},
        {'kind': 'reply', 'text': _sentinel, 'remaining': _sentinel},
        {
          'kind': 'reply',
          'text': 'ok',
          'remaining': {'daily': _sentinel, 'monthly': 1},
        },
        {
          'kind': 'reply',
          'text': 'ok',
          'remaining': {'daily': 1, 'monthly': _sentinel},
        },
      ];

      for (final payload in malformed) {
        try {
          coachReplyFromCallable(payload);
          fail('expected a FormatException for the malformed payload');
        } on FormatException catch (error) {
          expect(error.toString(), isNot(contains(_sentinel)));
        }
      }
    });
  });

  group(
    'decodeOrThrowCoachException — parse failure converts in the data layer',
    () {
      test('a valid payload decodes to the reply', () {
        final reply = decodeOrThrowCoachException({
          'kind': 'reply',
          'text': 'ok',
        });
        expect(reply.kind, CoachReplyKind.reply);
      });

      test(
        'a malformed payload converts to CoachUnknownException(malformed-response)',
        () {
          Object? thrown;
          try {
            decodeOrThrowCoachException({'kind': 'nope', 'text': 'x'});
          } catch (error) {
            thrown = error;
          }

          expect(thrown, isA<CoachUnknownException>());
          final unknown = thrown! as CoachUnknownException;
          expect(unknown.code, 'malformed-response');
          expect(unknown.message, isNull);
        },
      );

      test(
        'the converted exception never carries the malformed content (sentinel)',
        () {
          Object? thrown;
          try {
            decodeOrThrowCoachException({'kind': _sentinel, 'text': 'ok'});
          } catch (error) {
            thrown = error;
          }

          expect(thrown, isA<CoachUnknownException>());
          expect(thrown.toString(), isNot(contains(_sentinel)));
        },
      );
    },
  );

  group('mapCoachFailure — code-first, reason-refined matrix', () {
    CoachException map(String code, [String? reason]) => mapCoachFailure(
      _FunctionsException(
        code: code,
        details: reason == null ? null : {'reason': reason},
      ),
    );

    test('permission-denied → not-member', () {
      expect(map('permission-denied'), isA<CoachNotMemberException>());
    });

    test('failed-precondition → not-premium on code alone (any/no reason)', () {
      expect(map('failed-precondition'), isA<CoachNotPremiumException>());
      expect(
        map('failed-precondition', 'not-premium'),
        isA<CoachNotPremiumException>(),
      );
      expect(
        map('failed-precondition', 'anything-else'),
        isA<CoachNotPremiumException>(),
      );
    });

    test('resource-exhausted refines on the reason', () {
      expect(
        map('resource-exhausted', 'cap-daily'),
        isA<CoachDailyCapException>(),
      );
      expect(
        map('resource-exhausted', 'cap-monthly'),
        isA<CoachMonthlyCapException>(),
      );
      expect(
        map('resource-exhausted', 'rate-limited'),
        isA<CoachRateLimitedException>(),
      );
    });

    test('resource-exhausted with absent/junk reason → neutral limit', () {
      expect(map('resource-exhausted'), isA<CoachLimitReachedException>());
      expect(
        map('resource-exhausted', 'brand-new-reason'),
        isA<CoachLimitReachedException>(),
      );
    });

    test(
      'resource-exhausted with a non-map / non-string reason → neutral limit',
      () {
        expect(
          mapCoachFailure(
            _FunctionsException(code: 'resource-exhausted', details: 'oops'),
          ),
          isA<CoachLimitReachedException>(),
        );
        expect(
          mapCoachFailure(
            _FunctionsException(
              code: 'resource-exhausted',
              details: {'reason': 123},
            ),
          ),
          isA<CoachLimitReachedException>(),
        );
      },
    );

    test('unavailable / deadline-exceeded → unavailable', () {
      expect(map('unavailable'), isA<CoachUnavailableException>());
      expect(map('deadline-exceeded'), isA<CoachUnavailableException>());
    });

    test('any other code → unknown, keeping the raw code + static message', () {
      for (final code in ['invalid-argument', 'internal', 'unauthenticated']) {
        final failure = map(code);
        expect(failure, isA<CoachUnknownException>());
        expect((failure as CoachUnknownException).code, code);
        expect(failure.message, 'boom');
      }
    });
  });

  group('mapCoachFailure — non-Functions throws (runtimeType only)', () {
    test(
      'wraps as unexpected with the runtimeType as message, never the value',
      () {
        final error = StateError(_sentinel);

        final mapped = mapCoachFailure(error);

        expect(mapped, isA<CoachUnknownException>());
        final unknown = mapped as CoachUnknownException;
        expect(unknown.code, 'unexpected');
        expect(unknown.message, error.runtimeType.toString());
        expect(unknown.toString(), isNot(contains(_sentinel)));
      },
    );

    test('a FormatException throwable also degrades to runtimeType only', () {
      final mapped = mapCoachFailure(const FormatException(_sentinel));

      expect(mapped, isA<CoachUnknownException>());
      expect((mapped as CoachUnknownException).code, 'unexpected');
      expect(mapped.toString(), isNot(contains(_sentinel)));
    });
  });
}
