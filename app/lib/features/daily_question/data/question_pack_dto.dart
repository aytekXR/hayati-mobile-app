import '../../profile/domain/relationship_profile.dart';
import '../domain/question.dart';

/// Wire mapping for question packs (promoted from the M2.4 solo mapper,
/// M3.1): pure functions over decoded JSON shaped like
/// `content/schema/question-pack.schema.json`. Loud discipline: any
/// deviation from the schema contract throws [FormatException] naming the
/// offending field — a malformed bundled asset is a packaging bug that must
/// surface, never a silently shortened cycle. The `content/` pipeline
/// enforces the full schema (additionalProperties, filename↔packId,
/// cross-pack id uniqueness) at CI time; this mapper re-checks everything a
/// single decoded document can prove at runtime.
///
/// Schema fields crossing into the domain since M3.1: `register` (pack) and
/// `seasonalWindow` (question) — the M3.2 selection inputs. `reviewedBy`
/// stays validator-owned: a shippability flag, not app behaviour.
QuestionPack questionPackFromJson(Map<String, dynamic> json) {
  final packId = _stringField(json, 'packId');
  final version = _intField(json, 'version');
  if (version < 1) {
    throw FormatException('question pack "$packId": version must be >= 1');
  }
  final language = _localeField(json, packId);
  final register = _registerField(json, packId);

  final rawQuestions = json['questions'];
  if (rawQuestions is! List || rawQuestions.isEmpty) {
    throw FormatException(
      'question pack "$packId": questions must be a '
      'non-empty array',
    );
  }
  final seenIds = <String>{};
  final questions = <Question>[];
  for (final raw in rawQuestions) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException(
        'question pack "$packId": question entries must be '
        'objects, got ${raw.runtimeType}',
      );
    }
    final question = _questionFromJson(raw, packId);
    if (!seenIds.add(question.id)) {
      throw FormatException(
        'question pack "$packId": duplicate question id "${question.id}"',
      );
    }
    questions.add(question);
  }

  return QuestionPack(
    packId: packId,
    version: version,
    language: language,
    register: register,
    questions: questions,
  );
}

Question _questionFromJson(Map<String, dynamic> json, String packId) {
  final id = _stringField(json, 'id', context: 'pack "$packId"');
  final text = _stringField(json, 'text', context: 'question "$id"');
  final depth = _intField(json, 'depth', context: 'question "$id"');
  if (depth < 1 || depth > 5) {
    throw FormatException('question "$id": depth must be 1-5, got $depth');
  }
  final rawCategory = _stringField(json, 'category', context: 'question "$id"');
  final category = QuestionCategory.values
      .where((value) => value.name == rawCategory)
      .firstOrNull;
  if (category == null) {
    throw FormatException('question "$id": unknown category "$rawCategory"');
  }
  String? seasonalWindow;
  if (json.containsKey('seasonalWindow')) {
    seasonalWindow = _stringField(
      json,
      'seasonalWindow',
      context: 'question "$id"',
    );
  }
  return Question(
    id: id,
    category: category,
    depth: depth,
    text: text,
    seasonalWindow: seasonalWindow,
  );
}

ContentLanguage _localeField(Map<String, dynamic> json, String packId) {
  final raw = _stringField(json, 'locale', context: 'pack "$packId"');
  final language = ContentLanguage.values
      .where((value) => value.name == raw)
      .firstOrNull;
  if (language == null) {
    throw FormatException('question pack "$packId": unknown locale "$raw"');
  }
  return language;
}

QuestionRegister _registerField(Map<String, dynamic> json, String packId) {
  final raw = _stringField(json, 'register', context: 'pack "$packId"');
  final register = QuestionRegister.values
      .where((value) => value.wire == raw)
      .firstOrNull;
  if (register == null) {
    throw FormatException('question pack "$packId": unknown register "$raw"');
  }
  return register;
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
