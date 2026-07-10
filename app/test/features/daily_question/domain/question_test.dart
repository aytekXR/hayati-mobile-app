import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

void main() {
  const question = Question(
    id: 'solo_en_001',
    category: QuestionCategory.gratitude,
    depth: 1,
    text: 'What are you grateful for?',
  );

  group('Question', () {
    test('value equality is field-based', () {
      expect(
        question,
        const Question(
          id: 'solo_en_001',
          category: QuestionCategory.gratitude,
          depth: 1,
          text: 'What are you grateful for?',
        ),
      );
      expect(
        question.hashCode,
        const Question(
          id: 'solo_en_001',
          category: QuestionCategory.gratitude,
          depth: 1,
          text: 'What are you grateful for?',
        ).hashCode,
      );
      expect(
        question,
        isNot(
          const Question(
            id: 'solo_en_002',
            category: QuestionCategory.gratitude,
            depth: 1,
            text: 'What are you grateful for?',
          ),
        ),
      );
    });

    test('seasonalWindow participates in equality (evergreen != seasonal)', () {
      expect(
        question,
        isNot(
          const Question(
            id: 'solo_en_001',
            category: QuestionCategory.gratitude,
            depth: 1,
            text: 'What are you grateful for?',
            seasonalWindow: 'ramadan',
          ),
        ),
      );
    });

    test('toString names the id for diagnostics', () {
      expect(question.toString(), contains('solo_en_001'));
    });

    test('captures the schema category vocabulary exactly', () {
      // content/schema/question-pack.schema.json category enum: fun, deep,
      // memories, future, gratitude. A new value is a content-format
      // decision, so pin the set.
      expect(QuestionCategory.values, hasLength(5));
    });
  });

  group('QuestionRegister', () {
    test('wire names match the schema register enum exactly', () {
      // The validator cross-checks the schema file against its own copy of
      // this vocabulary in CI; this pins the domain's copy to the same set.
      expect(QuestionRegister.values.map((r) => r.wire), [
        'playful',
        'respectful',
        'msa_gulf',
        'neutral',
      ]);
    });
  });

  group('QuestionPack', () {
    const questions = [question];
    const pack = QuestionPack(
      packId: 'solo_en',
      version: 1,
      language: ContentLanguage.en,
      register: QuestionRegister.neutral,
      questions: questions,
    );

    test('value equality includes the question list', () {
      expect(
        pack,
        const QuestionPack(
          packId: 'solo_en',
          version: 1,
          language: ContentLanguage.en,
          register: QuestionRegister.neutral,
          questions: [question],
        ),
      );
      expect(
        pack,
        isNot(
          const QuestionPack(
            packId: 'solo_en',
            version: 1,
            language: ContentLanguage.en,
            register: QuestionRegister.neutral,
            questions: [
              Question(
                id: 'solo_en_009',
                category: QuestionCategory.fun,
                depth: 1,
                text: 'Different',
              ),
            ],
          ),
        ),
      );
      expect(
        pack,
        isNot(
          const QuestionPack(
            packId: 'solo_en',
            version: 2,
            language: ContentLanguage.en,
            register: QuestionRegister.neutral,
            questions: questions,
          ),
        ),
      );
    });

    test('register participates in equality (M3.2 selection input)', () {
      expect(
        pack,
        isNot(
          const QuestionPack(
            packId: 'solo_en',
            version: 1,
            language: ContentLanguage.en,
            register: QuestionRegister.playful,
            questions: questions,
          ),
        ),
      );
    });

    test('toString reports the question count, not the content', () {
      expect(pack.toString(), contains('questions: 1'));
    });
  });
}
