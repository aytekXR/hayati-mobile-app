import '../../profile/domain/relationship_profile.dart';

/// Question category vocabulary, mirroring the `category` enum in
/// `content/schema/question-pack.schema.json`. Wire names are the Dart
/// `name`s — renaming a member is a content-format migration, not a refactor.
enum SoloQuestionCategory { fun, deep, memories, future, gratitude }

/// One reflection question from a solo pack (M2.4). Pure Dart; shaped after
/// the question object in `content/schema/question-pack.schema.json` so the
/// M3 pack pipeline inherits the model rather than replacing it.
class SoloQuestion {
  const SoloQuestion({
    required this.id,
    required this.category,
    required this.depth,
    required this.text,
  });

  final String id;
  final SoloQuestionCategory category;

  /// 1 = icebreaker … 5 = deepest (schema `depth`; drives M4 depth gating).
  final int depth;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoloQuestion &&
          other.id == id &&
          other.category == category &&
          other.depth == depth &&
          other.text == text;

  @override
  int get hashCode => Object.hash(id, category, depth, text);

  @override
  String toString() =>
      'SoloQuestion(id: $id, category: $category, depth: $depth, text: $text)';
}

/// A bundled solo question pack (M2.4): the 7-day reflection cycle for one
/// [ContentLanguage], loaded from the schema-shaped JSON asset under
/// `app/assets/content/`. The register dimension deliberately does NOT cross
/// into the domain yet — solo packs ship register-neutral and full pack
/// resolution (register-aware, remote-synced) is M3.
class SoloQuestionPack {
  const SoloQuestionPack({
    required this.packId,
    required this.version,
    required this.language,
    required this.questions,
  });

  final String packId;
  final int version;
  final ContentLanguage language;

  /// Day 1 answers `questions[0]` … day 7 `questions[6]`
  /// (`soloQuestionForDay`). The asset repository enforces exactly
  /// [soloQuestionDays] entries at load, so the rotation can index directly.
  final List<SoloQuestion> questions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoloQuestionPack &&
          other.packId == packId &&
          other.version == version &&
          other.language == language &&
          _sameQuestions(other.questions, questions);

  @override
  int get hashCode =>
      Object.hash(packId, version, language, Object.hashAll(questions));

  @override
  String toString() =>
      'SoloQuestionPack(packId: $packId, version: $version, '
      'language: $language, questions: ${questions.length})';

  static bool _sameQuestions(List<SoloQuestion> a, List<SoloQuestion> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
