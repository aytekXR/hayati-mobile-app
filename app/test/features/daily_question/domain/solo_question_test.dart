import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

void main() {
  const question = SoloQuestion(
    id: 'solo_en_001',
    category: SoloQuestionCategory.gratitude,
    depth: 1,
    text: 'What are you grateful for?',
  );

  group('SoloQuestion', () {
    test('value equality is field-based', () {
      expect(
        question,
        const SoloQuestion(
          id: 'solo_en_001',
          category: SoloQuestionCategory.gratitude,
          depth: 1,
          text: 'What are you grateful for?',
        ),
      );
      expect(
        question.hashCode,
        const SoloQuestion(
          id: 'solo_en_001',
          category: SoloQuestionCategory.gratitude,
          depth: 1,
          text: 'What are you grateful for?',
        ).hashCode,
      );
      expect(
        question,
        isNot(
          const SoloQuestion(
            id: 'solo_en_002',
            category: SoloQuestionCategory.gratitude,
            depth: 1,
            text: 'What are you grateful for?',
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
      expect(SoloQuestionCategory.values, hasLength(5));
    });
  });

  group('SoloQuestionPack', () {
    const questions = [question];
    const pack = SoloQuestionPack(
      packId: 'solo_en',
      version: 1,
      language: ContentLanguage.en,
      questions: questions,
    );

    test('value equality includes the question list', () {
      expect(
        pack,
        const SoloQuestionPack(
          packId: 'solo_en',
          version: 1,
          language: ContentLanguage.en,
          questions: [question],
        ),
      );
      expect(
        pack,
        isNot(
          const SoloQuestionPack(
            packId: 'solo_en',
            version: 1,
            language: ContentLanguage.en,
            questions: [
              SoloQuestion(
                id: 'solo_en_009',
                category: SoloQuestionCategory.fun,
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
          const SoloQuestionPack(
            packId: 'solo_en',
            version: 2,
            language: ContentLanguage.en,
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
