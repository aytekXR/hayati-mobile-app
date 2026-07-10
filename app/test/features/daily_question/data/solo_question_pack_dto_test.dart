import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/solo_question_pack_dto.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// A schema-valid single-question pack; tests mutate copies of it to hit each
/// loud branch.
Map<String, dynamic> validPack() => {
  'packId': 'solo_en',
  'version': 1,
  'locale': 'en',
  'register': 'neutral',
  'reviewedBy': 'someone',
  'questions': [
    {
      'id': 'solo_en_001',
      'category': 'gratitude',
      'depth': 1,
      'text': 'What are you grateful for?',
    },
  ],
};

void main() {
  group('soloQuestionPackFromJson', () {
    test('maps a schema-shaped pack into the domain', () {
      final pack = soloQuestionPackFromJson(validPack());

      expect(pack.packId, 'solo_en');
      expect(pack.version, 1);
      expect(pack.language, ContentLanguage.en);
      expect(pack.questions, hasLength(1));
      expect(
        pack.questions.single,
        const SoloQuestion(
          id: 'solo_en_001',
          category: SoloQuestionCategory.gratitude,
          depth: 1,
          text: 'What are you grateful for?',
        ),
      );
    });

    test('tolerates schema fields the domain does not carry', () {
      // reviewedBy (pack) and seasonalWindow (question) are schema-legal and
      // owned by the M3 pipeline; reading past them must not throw.
      final json = validPack();
      (json['questions'] as List).add({
        'id': 'solo_en_002',
        'category': 'memories',
        'depth': 2,
        'seasonalWindow': 'new_year',
        'text': 'A seasonal one.',
      });

      expect(soloQuestionPackFromJson(json).questions, hasLength(2));
    });

    test('rejects a missing or empty packId loudly', () {
      expect(
        () => soloQuestionPackFromJson(validPack()..remove('packId')),
        throwsFormatException,
      );
      expect(
        () => soloQuestionPackFromJson(validPack()..['packId'] = ''),
        throwsFormatException,
      );
    });

    test('rejects a non-positive or non-int version loudly', () {
      expect(
        () => soloQuestionPackFromJson(validPack()..['version'] = 0),
        throwsFormatException,
      );
      expect(
        () => soloQuestionPackFromJson(validPack()..['version'] = '1'),
        throwsFormatException,
      );
    });

    test('rejects an unknown locale loudly', () {
      expect(
        () => soloQuestionPackFromJson(validPack()..['locale'] = 'de'),
        throwsFormatException,
      );
    });

    test('accepts every schema register and rejects unknown ones', () {
      for (final register in ['playful', 'respectful', 'msa_gulf', 'neutral']) {
        expect(
          soloQuestionPackFromJson(validPack()..['register'] = register),
          isA<SoloQuestionPack>(),
        );
      }
      expect(
        () => soloQuestionPackFromJson(validPack()..['register'] = 'formal'),
        throwsFormatException,
      );
    });

    test('rejects missing, empty or non-list questions loudly', () {
      expect(
        () => soloQuestionPackFromJson(validPack()..remove('questions')),
        throwsFormatException,
      );
      expect(
        () => soloQuestionPackFromJson(validPack()..['questions'] = <Object>[]),
        throwsFormatException,
      );
      expect(
        () => soloQuestionPackFromJson(validPack()..['questions'] = 'nope'),
        throwsFormatException,
      );
    });

    test('rejects a non-object question entry loudly', () {
      expect(
        () => soloQuestionPackFromJson(
          validPack()..['questions'] = ['just a string'],
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate question ids loudly', () {
      final json = validPack();
      (json['questions'] as List).add({
        'id': 'solo_en_001',
        'category': 'fun',
        'depth': 1,
        'text': 'A duplicate id.',
      });

      expect(() => soloQuestionPackFromJson(json), throwsFormatException);
    });

    test('rejects an unknown category loudly', () {
      final json = validPack();
      ((json['questions'] as List).single as Map<String, dynamic>)['category'] =
          'romance';

      expect(() => soloQuestionPackFromJson(json), throwsFormatException);
    });

    test('rejects an out-of-range depth loudly', () {
      for (final depth in [0, 6, 'deep']) {
        final json = validPack();
        ((json['questions'] as List).single as Map<String, dynamic>)['depth'] =
            depth;

        expect(() => soloQuestionPackFromJson(json), throwsFormatException);
      }
    });

    test('rejects missing or empty question text loudly', () {
      final json = validPack();
      ((json['questions'] as List).single as Map<String, dynamic>)['text'] = '';

      expect(() => soloQuestionPackFromJson(json), throwsFormatException);
    });
  });
}
