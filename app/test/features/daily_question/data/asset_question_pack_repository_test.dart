import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/asset_question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

import '../../../support/static_asset_bundle.dart';

/// A schema-valid pack JSON string with [count] questions.
String packJson({required String locale, int count = 7, String? packId}) =>
    jsonEncode({
      'packId': packId ?? 'solo_$locale',
      'version': 1,
      'locale': locale,
      'register': 'neutral',
      'questions': [
        for (var day = 1; day <= count; day++)
          {
            'id': '${packId ?? 'solo_$locale'}_00$day',
            'category': 'deep',
            'depth': 1,
            'text': 'Question $day',
          },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetQuestionPackRepository (generic, M3.1)', () {
    test(
      'loads a pack by packId with register and language surfaced',
      () async {
        final repository = AssetQuestionPackRepository(
          bundle: StaticAssetBundle({
            AssetQuestionPackRepository.assetPathFor('solo_en'): packJson(
              locale: 'en',
            ),
          }),
        );

        final pack = await repository.loadPack('solo_en');
        expect(pack.packId, 'solo_en');
        expect(pack.language, ContentLanguage.en);
        expect(pack.register, QuestionRegister.neutral);
        expect(pack.questions, isNotEmpty);
      },
    );

    test('is not solo-shaped: any question count loads (solo\'s exactly-7 '
        'is the specialization\'s job)', () async {
      final repository = AssetQuestionPackRepository(
        bundle: StaticAssetBundle({
          AssetQuestionPackRepository.assetPathFor('solo_en'): packJson(
            locale: 'en',
            count: 2,
          ),
        }),
      );

      expect((await repository.loadPack('solo_en')).questions, hasLength(2));
    });

    test('rejects a document whose packId disagrees with the asset name '
        '(a swapped asset must not serve another pack\'s content)', () {
      final repository = AssetQuestionPackRepository(
        bundle: StaticAssetBundle({
          AssetQuestionPackRepository.assetPathFor('solo_en'): packJson(
            locale: 'tr',
            packId: 'solo_tr',
          ),
        }),
      );

      expect(repository.loadPack('solo_en'), throwsFormatException);
    });

    test('rejects a non-object JSON root loudly', () {
      final repository = AssetQuestionPackRepository(
        bundle: StaticAssetBundle({
          AssetQuestionPackRepository.assetPathFor('solo_en'): '["not a pack"]',
        }),
      );

      expect(repository.loadPack('solo_en'), throwsFormatException);
    });
  });
}
