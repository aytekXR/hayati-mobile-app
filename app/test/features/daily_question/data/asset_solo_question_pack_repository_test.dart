import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/asset_solo_question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository.dart';
import 'package:hayati_app/features/daily_question/domain/solo_day.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// Serves canned strings as assets so the load contracts can be exercised
/// without touching the real bundle.
class _StaticAssetBundle extends AssetBundle {
  _StaticAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(await loadString(key));
}

/// A schema-valid pack JSON string with [count] questions.
String packJson({
  required String locale,
  int count = soloQuestionDays,
  String? packId,
}) => jsonEncode({
  'packId': packId ?? 'solo_$locale',
  'version': 1,
  'locale': locale,
  'register': 'neutral',
  'questions': [
    for (var day = 1; day <= count; day++)
      {
        'id': 'solo_${locale}_00$day',
        'category': 'deep',
        'depth': 1,
        'text': 'Question $day',
      },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the SHIPPED bundled packs', () {
    // These load the real assets/content/solo_<locale>.json through the real
    // rootBundle: the proof that what ships parses, matches its language and
    // carries exactly the 7-day cycle (docs/prd.md F1).
    for (final language in ContentLanguage.values) {
      test('solo_${language.name}.json is valid, 7 questions, '
          'unique namespaced ids', () async {
        const repository = AssetSoloQuestionPackRepository();
        final pack = await repository.loadPack(language);

        expect(pack.packId, 'solo_${language.name}');
        expect(pack.language, language);
        expect(pack.questions, hasLength(soloQuestionDays));
        expect(
          pack.questions.map((question) => question.id).toSet(),
          hasLength(soloQuestionDays),
        );
        for (final question in pack.questions) {
          expect(question.id, startsWith('solo_${language.name}_'));
          expect(question.text.trim(), isNotEmpty);
        }
      });
    }
  });

  group('load contracts', () {
    test('rejects a pack whose locale does not match the request', () {
      // packId matches the request so the generic packId↔asset-name check
      // passes; the solo wrapper's own locale check must still refuse it.
      final repository = AssetSoloQuestionPackRepository(
        bundle: _StaticAssetBundle({
          AssetSoloQuestionPackRepository.assetPathFor(ContentLanguage.en):
              packJson(locale: 'tr', packId: 'solo_en'),
        }),
      );

      expect(repository.loadPack(ContentLanguage.en), throwsFormatException);
    });

    test('rejects a cycle that is not exactly 7 questions', () {
      final short = AssetSoloQuestionPackRepository(
        bundle: _StaticAssetBundle({
          AssetSoloQuestionPackRepository.assetPathFor(ContentLanguage.en):
              packJson(locale: 'en', count: 6),
        }),
      );
      final long = AssetSoloQuestionPackRepository(
        bundle: _StaticAssetBundle({
          AssetSoloQuestionPackRepository.assetPathFor(ContentLanguage.en):
              packJson(locale: 'en', count: 8),
        }),
      );

      expect(short.loadPack(ContentLanguage.en), throwsFormatException);
      expect(long.loadPack(ContentLanguage.en), throwsFormatException);
    });

    test('rejects a non-object JSON root loudly', () {
      final repository = AssetSoloQuestionPackRepository(
        bundle: _StaticAssetBundle({
          AssetSoloQuestionPackRepository.assetPathFor(ContentLanguage.en):
              '["not a pack"]',
        }),
      );

      expect(repository.loadPack(ContentLanguage.en), throwsFormatException);
    });

    test('a missing asset propagates as a load failure (packaging bug '
        'surfaces, never a silent empty cycle)', () {
      final repository = AssetSoloQuestionPackRepository(
        bundle: _StaticAssetBundle(const {}),
      );

      // Since M3.3 the generic loader types the absent-asset path as
      // UnknownQuestionPackException (pack-lag semantics for day-doc ids);
      // for the solo derivation it is still what it always was — a loud
      // packaging failure, never a silent empty cycle.
      expect(
        repository.loadPack(ContentLanguage.en),
        throwsA(isA<UnknownQuestionPackException>()),
      );
    });
  });
}
