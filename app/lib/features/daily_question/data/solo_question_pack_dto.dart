import '../../profile/domain/relationship_profile.dart';
import '../domain/solo_question.dart';

/// Wire mapping for the bundled solo packs (M2.4): pure functions over the
/// decoded JSON of `app/assets/content/solo_<locale>.json`, which is shaped
/// like `content/schema/question-pack.schema.json`. Loud discipline: any
/// deviation from the schema contract throws [FormatException] naming the
/// offending field — a malformed bundled asset is a packaging bug that must
/// surface, never a silently shortened cycle. (The enforcing validator/CI
/// pipeline for `content/` proper is M3; this mapper is the app-side
/// contract-keeper until then.)
///
/// Schema fields deliberately NOT crossing into the domain: `register` and
/// `reviewedBy` (validated for shape, owned by the M3 pack-resolution work)
/// and per-question `seasonalWindow` (solo packs are evergreen).
SoloQuestionPack soloQuestionPackFromJson(Map<String, dynamic> json) {
  final packId = _stringField(json, 'packId');
  final version = _intField(json, 'version');
  if (version < 1) {
    throw FormatException('solo pack "$packId": version must be >= 1');
  }
  final language = _localeField(json, packId);
  _validateRegister(json, packId);

  final rawQuestions = json['questions'];
  if (rawQuestions is! List || rawQuestions.isEmpty) {
    throw FormatException(
      'solo pack "$packId": questions must be a '
      'non-empty array',
    );
  }
  final seenIds = <String>{};
  final questions = <SoloQuestion>[];
  for (final raw in rawQuestions) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException(
        'solo pack "$packId": question entries must be '
        'objects, got ${raw.runtimeType}',
      );
    }
    final question = _questionFromJson(raw, packId);
    if (!seenIds.add(question.id)) {
      throw FormatException(
        'solo pack "$packId": duplicate question id "${question.id}"',
      );
    }
    questions.add(question);
  }

  return SoloQuestionPack(
    packId: packId,
    version: version,
    language: language,
    questions: questions,
  );
}

SoloQuestion _questionFromJson(Map<String, dynamic> json, String packId) {
  final id = _stringField(json, 'id', context: 'pack "$packId"');
  final text = _stringField(json, 'text', context: 'question "$id"');
  final depth = _intField(json, 'depth', context: 'question "$id"');
  if (depth < 1 || depth > 5) {
    throw FormatException('question "$id": depth must be 1-5, got $depth');
  }
  final rawCategory = _stringField(json, 'category', context: 'question "$id"');
  final category = SoloQuestionCategory.values
      .where((value) => value.name == rawCategory)
      .firstOrNull;
  if (category == null) {
    throw FormatException('question "$id": unknown category "$rawCategory"');
  }
  return SoloQuestion(id: id, category: category, depth: depth, text: text);
}

ContentLanguage _localeField(Map<String, dynamic> json, String packId) {
  final raw = _stringField(json, 'locale', context: 'pack "$packId"');
  final language = ContentLanguage.values
      .where((value) => value.name == raw)
      .firstOrNull;
  if (language == null) {
    throw FormatException('solo pack "$packId": unknown locale "$raw"');
  }
  return language;
}

/// The schema's register enum. Solo packs ship `neutral` (register-aware
/// pack resolution is M3), but the mapper accepts the full vocabulary so it
/// doesn't have to change when M3 reuses it.
const _knownRegisters = {'playful', 'respectful', 'msa_gulf', 'neutral'};

void _validateRegister(Map<String, dynamic> json, String packId) {
  final raw = _stringField(json, 'register', context: 'pack "$packId"');
  if (!_knownRegisters.contains(raw)) {
    throw FormatException('solo pack "$packId": unknown register "$raw"');
  }
}

String _stringField(
  Map<String, dynamic> json,
  String field, {
  String? context,
}) {
  final raw = json[field];
  final where = context == null ? '' : '$context: ';
  if (raw is! String || raw.isEmpty) {
    throw FormatException(
      '$where"$field" must be a non-empty string, got '
      '${raw is String ? 'an empty string' : raw.runtimeType}',
    );
  }
  return raw;
}

int _intField(Map<String, dynamic> json, String field, {String? context}) {
  final raw = json[field];
  final where = context == null ? '' : '$context: ';
  if (raw is! int) {
    throw FormatException(
      '$where"$field" must be an integer, got ${raw.runtimeType}',
    );
  }
  return raw;
}
