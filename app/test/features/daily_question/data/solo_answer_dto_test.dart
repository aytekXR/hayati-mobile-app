import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/solo_answer_dto.dart';

void main() {
  group('soloAnswerFromMap', () {
    test('maps a boundary-converted document into the domain', () {
      final answer = soloAnswerFromMap({
        'questionId': 'solo_en_003',
        'text': 'A quiet morning together.',
        'answeredAt': DateTime.utc(2026, 7, 10, 12),
      });

      expect(answer.questionId, 'solo_en_003');
      expect(answer.text, 'A quiet morning together.');
      expect(answer.answeredAt, DateTime.utc(2026, 7, 10, 12));
    });

    test('a pending server stamp (null answeredAt) crosses as null', () {
      final answer = soloAnswerFromMap({
        'questionId': 'solo_en_003',
        'text': 'Hi',
        'answeredAt': null,
      });

      expect(answer.answeredAt, isNull);
    });

    test('rejects a raw Timestamp answeredAt loudly (missed boundary '
        'conversion)', () {
      expect(
        () => soloAnswerFromMap({
          'questionId': 'solo_en_003',
          'text': 'Hi',
          'answeredAt': Timestamp.fromMillisecondsSinceEpoch(1751980000000),
        }),
        throwsFormatException,
      );
    });

    test('rejects missing or wrongly-typed fields loudly', () {
      expect(() => soloAnswerFromMap({'text': 'Hi'}), throwsFormatException);
      expect(
        () => soloAnswerFromMap({'questionId': 'q', 'text': 42}),
        throwsFormatException,
      );
    });
  });
}
