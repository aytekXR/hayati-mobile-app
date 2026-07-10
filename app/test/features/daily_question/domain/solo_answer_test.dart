import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer.dart';

void main() {
  group('SoloAnswer', () {
    final answered = SoloAnswer(
      questionId: 'solo_en_001',
      text: 'A quiet morning together.',
      answeredAt: DateTime.utc(2026, 7, 10, 12),
    );

    test('value equality is field-based', () {
      expect(
        answered,
        SoloAnswer(
          questionId: 'solo_en_001',
          text: 'A quiet morning together.',
          answeredAt: DateTime.utc(2026, 7, 10, 12),
        ),
      );
      expect(
        answered.hashCode,
        SoloAnswer(
          questionId: 'solo_en_001',
          text: 'A quiet morning together.',
          answeredAt: DateTime.utc(2026, 7, 10, 12),
        ).hashCode,
      );
      expect(
        answered,
        isNot(
          SoloAnswer(
            questionId: 'solo_en_001',
            text: 'A different answer.',
            answeredAt: DateTime.utc(2026, 7, 10, 12),
          ),
        ),
      );
    });

    test('a pending server stamp (null answeredAt) participates in '
        'equality', () {
      const pending = SoloAnswer(questionId: 'solo_en_001', text: 'Hi');
      expect(pending.answeredAt, isNull);
      expect(pending, isNot(answered));
    });

    test('toString names the question id for diagnostics', () {
      expect(answered.toString(), contains('solo_en_001'));
    });
  });
}
