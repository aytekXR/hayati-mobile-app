import 'package:flutter/services.dart' show AssetBundle;

import '../../profile/domain/relationship_profile.dart';
import '../domain/question.dart';
import '../domain/solo_day.dart';
import '../domain/solo_question_pack_repository.dart';
import 'asset_question_pack_repository.dart';

/// The solo specialization of [AssetQuestionPackRepository] (M3.1; loading
/// decision in docs/adr/009): a solo pack is just a bundled pack named
/// `solo_<locale>` — this wrapper resolves the packId from the requested
/// [ContentLanguage] and enforces the two SOLO-specific contracts on top of
/// the generic load: the pack's locale matches the requested language (a
/// swapped asset must not ship a Turkish cycle to an Arabic profile), and
/// the cycle is exactly [soloQuestionDays] questions long (docs/prd.md F1)
/// so day-N indexing can never over- or under-run.
class AssetSoloQuestionPackRepository implements SoloQuestionPackRepository {
  const AssetSoloQuestionPackRepository({this._bundle});

  final AssetBundle? _bundle;

  static String packIdFor(ContentLanguage language) => 'solo_${language.name}';

  static String assetPathFor(ContentLanguage language) =>
      AssetQuestionPackRepository.assetPathFor(packIdFor(language));

  @override
  Future<QuestionPack> loadPack(ContentLanguage language) async {
    final packs = AssetQuestionPackRepository(bundle: _bundle);
    final pack = await packs.loadPack(packIdFor(language));
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
