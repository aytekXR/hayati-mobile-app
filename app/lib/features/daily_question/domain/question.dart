import '../../profile/domain/relationship_profile.dart';

/// Question category vocabulary, mirroring the `category` enum in
/// `content/schema/question-pack.schema.json`. Wire names are the Dart
/// `name`s — renaming a member is a content-format migration, not a refactor.
enum QuestionCategory { fun, deep, memories, future, gratitude }

/// Tone register vocabulary (`content/schema/question-pack.schema.json`,
/// docs/frontend-brandkit.md §7). Carried on every pack since M3.1 so the
/// M3.2 register-aware resolution selects on the domain, not on raw JSON;
/// [wire] is the schema spelling (`msa_gulf` ≠ Dart-safe `msaGulf`).
enum QuestionRegister {
  playful('playful'),
  respectful('respectful'),
  msaGulf('msa_gulf'),
  neutral('neutral');

  const QuestionRegister(this.wire);

  final String wire;
}

/// One question from a pack. Pure Dart; shaped after the question object in
/// `content/schema/question-pack.schema.json` (promoted from the M2.4
/// `SoloQuestion` — same fields plus [seasonalWindow], M3.1).
class Question {
  const Question({
    required this.id,
    required this.category,
    required this.depth,
    required this.text,
    this.seasonalWindow,
  });

  final String id;
  final QuestionCategory category;

  /// 1 = icebreaker … 5 = deepest (schema `depth`; drives M4 depth gating).
  final int depth;
  final String text;

  /// Schema `seasonalWindow` (e.g. `ramadan`, `eid`, `new_year`); null =
  /// evergreen. Free-form by schema design — window→date resolution is the
  /// M3.2 rollover's job, so the domain carries the tag verbatim.
  final String? seasonalWindow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Question &&
          other.id == id &&
          other.category == category &&
          other.depth == depth &&
          other.text == text &&
          other.seasonalWindow == seasonalWindow;

  @override
  int get hashCode => Object.hash(id, category, depth, text, seasonalWindow);

  @override
  String toString() =>
      'Question(id: $id, category: $category, depth: $depth, '
      'seasonalWindow: $seasonalWindow, text: $text)';
}

/// A question pack: the schema-shaped unit of content for one
/// [ContentLanguage] and one [QuestionRegister], loaded from JSON bundled
/// under `app/assets/content/` (authored under `content/packs/`, synced by
/// the M3.1 validator pipeline). Promoted from the M2.4 `SoloQuestionPack`;
/// a solo pack is just a pack with exactly 7 questions (the solo repository
/// enforces that specialization at load).
class QuestionPack {
  const QuestionPack({
    required this.packId,
    required this.version,
    required this.language,
    required this.register,
    required this.questions,
  });

  final String packId;
  final int version;
  final ContentLanguage language;
  final QuestionRegister register;
  final List<Question> questions;

  /// The question with [id], or null when the bundled pack does not carry
  /// it (M3.3: the day doc's assignment can reference a newer pack version
  /// than the installed bundle — the honest "update the app" state, never a
  /// guessed question). Ids are unique within a pack (load-enforced), so
  /// first match is the match.
  Question? questionById(String id) {
    for (final question in questions) {
      if (question.id == id) return question;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionPack &&
          other.packId == packId &&
          other.version == version &&
          other.language == language &&
          other.register == register &&
          _sameQuestions(other.questions, questions);

  @override
  int get hashCode => Object.hash(
    packId,
    version,
    language,
    register,
    Object.hashAll(questions),
  );

  @override
  String toString() =>
      'QuestionPack(packId: $packId, version: $version, language: $language, '
      'register: $register, questions: ${questions.length})';

  static bool _sameQuestions(List<Question> a, List<Question> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
