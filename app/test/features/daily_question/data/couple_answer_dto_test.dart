import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/couple_answer_dto.dart';

void main() {
  group('coupleAnswerFromMap', () {
    test('maps a boundary-converted document into the domain', () {
      final answer = coupleAnswerFromMap({
        'questionId': 'solo_en_003',
        'text': 'A quiet morning together.',
        'answeredAt': DateTime.utc(2026, 7, 10, 12),
      });

      expect(answer.questionId, 'solo_en_003');
      expect(answer.text, 'A quiet morning together.');
      expect(answer.answeredAt, DateTime.utc(2026, 7, 10, 12));
    });

    test('a pending server stamp (null answeredAt) crosses as null', () {
      // The partner-slot gate keys off exactly this null: the reveal stream
      // attaches only once the own answer is server-acked (answeredAt set).
      final answer = coupleAnswerFromMap({
        'questionId': 'solo_en_003',
        'text': 'Hi',
        'answeredAt': null,
      });

      expect(answer.answeredAt, isNull);
    });

    test('accepts empty questionId and text — the rules own that bound, not '
        'the mapper', () {
      // Deliberate divergence from coupleFromMap (which rejects empties): the
      // answers rules cap text (<= 2000) and pin questionId, so this pure
      // mapper guards only the TYPE, leaving the server the single bound.
      final answer = coupleAnswerFromMap({
        'questionId': '',
        'text': '',
        'answeredAt': DateTime.utc(2026, 7, 10, 12),
      });

      expect(answer.questionId, isEmpty);
      expect(answer.text, isEmpty);
    });

    test('rejects a raw Timestamp answeredAt loudly (missed boundary '
        'conversion)', () {
      expect(
        () => coupleAnswerFromMap({
          'questionId': 'solo_en_003',
          'text': 'Hi',
          'answeredAt': Timestamp.fromMillisecondsSinceEpoch(1751980000000),
        }),
        throwsFormatException,
      );
    });

    test('rejects a missing or wrongly-typed questionId/text loudly', () {
      expect(() => coupleAnswerFromMap({'text': 'Hi'}), throwsFormatException);
      expect(
        () => coupleAnswerFromMap({'questionId': 'q', 'text': 42}),
        throwsFormatException,
      );
    });
  });
}
