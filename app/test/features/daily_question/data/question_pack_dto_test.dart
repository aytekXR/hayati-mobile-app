import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/question_pack_dto.dart';
import 'package:hayati_app/features/daily_question/domain/question.dart';
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
  group('questionPackFromJson', () {
    test('maps a schema-shaped pack into the domain', () {
      final pack = questionPackFromJson(validPack());

      expect(pack.packId, 'solo_en');
      expect(pack.version, 1);
      expect(pack.language, ContentLanguage.en);
      expect(pack.register, QuestionRegister.neutral);
      expect(pack.questions, hasLength(1));
      expect(
        pack.questions.single,
        const Question(
          id: 'solo_en_001',
          category: QuestionCategory.gratitude,
          depth: 1,
          text: 'What are you grateful for?',
        ),
      );
    });

    test('carries seasonalWindow into the domain and defaults to evergreen '
        '(M3.1 — the M3.2 rollover selects on it)', () {
      final json = validPack();
      (json['questions'] as List).add({
        'id': 'solo_en_002',
        'category': 'memories',
        'depth': 2,
        'seasonalWindow': 'new_year',
        'text': 'A seasonal one.',
      });

      final pack = questionPackFromJson(json);
      expect(pack.questions.first.seasonalWindow, isNull);
      expect(pack.questions.last.seasonalWindow, 'new_year');
    });

    // NOT a parity guard, and it must not be mistaken for one — that mistake is
    // issue #130. Iterating `knownSeasonalWindows` proves the DTO accepts every
    // value the app already knows; it cannot detect that the app's list has
    // drifted from the schema, because the schema is never read here. A fixture
    // derived from its own subject proves only self-consistency.
    //
    // The actual parity net is `schema_enum_parity_test.dart`, which reads
    // `content/schema/question-pack.schema.json`. This case is kept because the
    // property it DOES check is real and distinct — the parse path accepts each
    // known value — and its name now says which of the two it is.
    test(
      'the DTO parse path accepts each KNOWN seasonal value (self-consistency '
      'only — schema parity lives in schema_enum_parity_test.dart)',
      () {
        for (final window in knownSeasonalWindows) {
          final json = validPack();
          ((json['questions'] as List).single
                  as Map<String, dynamic>)['seasonalWindow'] =
              window;
          expect(
            questionPackFromJson(json).questions.single.seasonalWindow,
            window,
          );
        }
      },
    );

    test('rejects a seasonalWindow outside the closed vocabulary (ADR-026 D3 '
        '— a tag nothing recognises is a question never selected)', () {
      for (final bogus in ['Ramadan', 'eid', 'ramadan_2027', 'newyear']) {
        final json = validPack();
        ((json['questions'] as List).single
                as Map<String, dynamic>)['seasonalWindow'] =
            bogus;
        expect(
          () => questionPackFromJson(json),
          throwsFormatException,
          reason: 'accepted "$bogus"',
        );
      }
    });

    test('rejects an empty seasonalWindow loudly', () {
      final json = validPack();
      ((json['questions'] as List).single
              as Map<String, dynamic>)['seasonalWindow'] =
          '';

      expect(() => questionPackFromJson(json), throwsFormatException);
    });

    test('tolerates schema fields the domain does not carry (reviewedBy is '
        'validator-owned)', () {
      expect(
        questionPackFromJson(validPack()..['reviewedBy'] = 'anyone'),
        isA<QuestionPack>(),
      );
    });

    test('rejects a missing or empty packId loudly', () {
      expect(
        () => questionPackFromJson(validPack()..remove('packId')),
        throwsFormatException,
      );
      expect(
        () => questionPackFromJson(validPack()..['packId'] = ''),
        throwsFormatException,
      );
    });

    test('rejects a non-positive or non-int version loudly', () {
      expect(
        () => questionPackFromJson(validPack()..['version'] = 0),
        throwsFormatException,
      );
      expect(
        () => questionPackFromJson(validPack()..['version'] = '1'),
        throwsFormatException,
      );
    });

    test('rejects an unknown locale loudly', () {
      expect(
        () => questionPackFromJson(validPack()..['locale'] = 'de'),
        throwsFormatException,
      );
    });

    test('maps every schema register into the domain and rejects unknown '
        'ones', () {
      const expected = {
        'playful': QuestionRegister.playful,
        'respectful': QuestionRegister.respectful,
        'msa_gulf': QuestionRegister.msaGulf,
        'neutral': QuestionRegister.neutral,
      };
      for (final entry in expected.entries) {
        expect(
          questionPackFromJson(validPack()..['register'] = entry.key).register,
          entry.value,
        );
      }
      expect(
        () => questionPackFromJson(validPack()..['register'] = 'formal'),
        throwsFormatException,
      );
    });

    test('rejects missing, empty or non-list questions loudly', () {
      expect(
        () => questionPackFromJson(validPack()..remove('questions')),
        throwsFormatException,
      );
      expect(
        () => questionPackFromJson(validPack()..['questions'] = <Object>[]),
        throwsFormatException,
      );
      expect(
        () => questionPackFromJson(validPack()..['questions'] = 'nope'),
        throwsFormatException,
      );
    });

    test('rejects a non-object question entry loudly', () {
      expect(
        () => questionPackFromJson(
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

      expect(() => questionPackFromJson(json), throwsFormatException);
    });

    test('rejects an unknown category loudly', () {
      final json = validPack();
      ((json['questions'] as List).single as Map<String, dynamic>)['category'] =
          'romance';

      expect(() => questionPackFromJson(json), throwsFormatException);
    });

    test('rejects an out-of-range depth loudly', () {
      for (final depth in [0, 6, 'deep']) {
        final json = validPack();
        ((json['questions'] as List).single as Map<String, dynamic>)['depth'] =
            depth;

        expect(() => questionPackFromJson(json), throwsFormatException);
      }
    });

    test('rejects missing or empty question text loudly', () {
      final json = validPack();
      ((json['questions'] as List).single as Map<String, dynamic>)['text'] = '';

      expect(() => questionPackFromJson(json), throwsFormatException);
    });
  });
}
