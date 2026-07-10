import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../profile/domain/relationship_profile.dart';
import '../domain/solo_day.dart';
import '../domain/solo_question.dart';
import '../domain/solo_question_pack_repository.dart';
import 'solo_question_pack_dto.dart';

/// Loads the bundled solo packs from `app/assets/content/solo_<locale>.json`
/// (M2.4, decision in docs/adr/009). The bundle is injectable so the plain
/// test VM can feed fixture bytes; production uses [rootBundle].
///
/// Beyond the schema-shape validation in [soloQuestionPackFromJson], this
/// enforces the two SOLO-specific contracts: the pack's locale matches the
/// requested language (a swapped asset must not ship a Turkish cycle to an
/// Arabic profile), and the cycle is exactly [soloQuestionDays] questions
/// long (docs/prd.md F1) so day-N indexing can never over- or under-run.
class AssetSoloQuestionPackRepository implements SoloQuestionPackRepository {
  const AssetSoloQuestionPackRepository({this._bundle});

  final AssetBundle? _bundle;

  static String assetPathFor(ContentLanguage language) =>
      'assets/content/solo_${language.name}.json';

  @override
  Future<SoloQuestionPack> loadPack(ContentLanguage language) async {
    final bundle = _bundle ?? rootBundle;
    final raw = await bundle.loadString(assetPathFor(language));
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'solo pack asset for "${language.name}": expected a JSON object, '
        'got ${decoded.runtimeType}',
      );
    }
    final pack = soloQuestionPackFromJson(decoded);
    if (pack.language != language) {
      throw FormatException(
        'solo pack "${pack.packId}": locale "${pack.language.name}" does not '
        'match the requested language "${language.name}"',
      );
    }
    if (pack.questions.length != soloQuestionDays) {
      throw FormatException(
        'solo pack "${pack.packId}": expected exactly $soloQuestionDays '
        'questions, got ${pack.questions.length}',
      );
    }
    return pack;
  }
}
