import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/daily_question/domain/solo_day.dart';
import 'package:hayati_app/features/daily_question/domain/solo_question_pack_repository.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// A deterministic 7-question pack for [language] with predictable texts —
/// `"EN solo question 3"` — so behaviour tests can assert the day-N selection
/// by literal text without depending on the shipped content (which the asset
/// repository tests pin separately).
QuestionPack soloPackFixture(ContentLanguage language) => QuestionPack(
  packId: 'solo_${language.name}',
  version: 1,
  language: language,
  register: QuestionRegister.neutral,
  questions: [
    for (var day = 1; day <= soloQuestionDays; day++)
      Question(
        id: 'solo_${language.name}_00$day',
        category: QuestionCategory.deep,
        depth: 1,
        text: '${language.name.toUpperCase()} solo question $day',
      ),
  ],
);

/// Hand-written fake backing the solo-home tests: serves [soloPackFixture]
/// packs by default, with the usual behaviour-knob override for failure /
/// never-completing states.
class FakeSoloQuestionPackRepository implements SoloQuestionPackRepository {
  /// Behaviour override for the next [loadPack] calls; default resolves the
  /// fixture pack for the requested language.
  Future<QuestionPack> Function(ContentLanguage language)? onLoadPack;

  int loadCalls = 0;

  @override
  Future<QuestionPack> loadPack(ContentLanguage language) {
    loadCalls++;
    final handler = onLoadPack;
    if (handler != null) return handler(language);
    return Future.value(soloPackFixture(language));
  }
}
