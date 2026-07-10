import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:hayati_app/features/daily_question/data/asset_solo_question_pack_repository.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// Serves canned strings as assets, completing without any platform-channel
/// I/O. Widget tests need this instead of `rootBundle`: the real bundle's
/// loads go through the flutter/assets channel, whose responses cannot
/// arrive inside the widget-test fake-async zone — a golden that watches a
/// rootBundle-backed provider wedges `pumpAndSettle`. (`rootBundle` itself —
/// and with it the pubspec `assets:` wiring — is still proven by the plain
/// `test()` cases in asset_solo_question_pack_repository_test.dart, which
/// run without fake async.)
class StaticAssetBundle extends AssetBundle {
  StaticAssetBundle(this._assets);

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

/// The REAL shipped solo packs (`app/assets/content/solo_<locale>.json`),
/// read synchronously off disk (`flutter test` runs with CWD `app/`) into a
/// [StaticAssetBundle] — so goldens render the actual product content while
/// staying fake-async-safe.
StaticAssetBundle shippedSoloPackBundle() => StaticAssetBundle({
  for (final language in ContentLanguage.values)
    AssetSoloQuestionPackRepository.assetPathFor(language): File(
      AssetSoloQuestionPackRepository.assetPathFor(language),
    ).readAsStringSync(),
});
