/// Pure validation core for Hayati question packs (M3.1).
///
/// Enforces `content/schema/question-pack.schema.json` — every field,
/// pattern, enum, and bound — plus the checks a JSON Schema cannot express:
/// question-id uniqueness ACROSS packs, `packId`↔filename↔`locale`
/// consistency, and the reviewedBy shippability flag (warning tier
/// pre-launch per ADR-007/W9; `--strict-review` promotes it at launch).
///
/// Pure by construction: no dart:io, no side effects — every function maps
/// inputs to a list of [PackIssue]s, so the self-tests
/// (`validator_core_test.dart`) cover it without touching the filesystem.
/// The thin IO shell is `validate.dart`.
library;

import 'dart:convert';

/// Schema vocabulary — single source inside the validator. `validate.dart`
/// cross-checks these against the JSON Schema file itself at every run, so
/// the schema and this core cannot drift apart silently.
const List<String> knownLocales = ['tr', 'ar', 'en'];
const List<String> knownRegisters = [
  'playful',
  'respectful',
  'msa_gulf',
  'neutral',
];
const List<String> knownCategories = [
  'fun',
  'deep',
  'memories',
  'future',
  'gratitude',
];
const int minDepth = 1;
const int maxDepth = 5;
const List<String> requiredPackFields = [
  'packId',
  'version',
  'locale',
  'register',
  'questions',
];
const List<String> optionalPackFields = ['reviewedBy'];
const List<String> requiredQuestionFields = ['id', 'category', 'depth', 'text'];
const List<String> optionalQuestionFields = ['seasonalWindow'];

/// `^[a-z0-9_]+$` — the schema pattern for packId and question id.
final RegExp idPattern = RegExp(r'^[a-z0-9_]+$');

enum IssueSeverity { error, warning }

/// One field-precise finding. [where] names the file (and field context) so
/// a red CI run points at the exact violation without local reproduction.
class PackIssue {
  const PackIssue(this.severity, this.where, this.message);

  final IssueSeverity severity;
  final String where;
  final String message;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() =>
      '${severity == IssueSeverity.error ? 'ERROR' : 'WARN '} $where: $message';
}

/// A successfully parsed pack plus its origin, carried into the cross-pack
/// checks ([validateAcrossPacks]).
class ParsedPack {
  const ParsedPack({required this.relativePath, required this.json});

  final String relativePath;
  final Map<String, dynamic> json;

  String get packId => json['packId'] is String ? json['packId'] as String : '';
}

/// Validates one pack source file. [relativePath] is the file's path as the
/// caller shows it (e.g. `content/packs/solo_tr.json`); the basename drives
/// the packId↔filename check. Returns issues; on a parse failure the single
/// error issue is the whole result. [strictReview] promotes the reviewedBy
/// shippability flag from warning to error (launch posture).
({List<PackIssue> issues, ParsedPack? pack}) validatePackSource({
  required String relativePath,
  required String source,
  bool strictReview = false,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    return (
      issues: [
        PackIssue(
          IssueSeverity.error,
          relativePath,
          'invalid JSON: ${e.message}',
        ),
      ],
      pack: null,
    );
  }
  if (decoded is! Map<String, dynamic>) {
    return (
      issues: [
        PackIssue(
          IssueSeverity.error,
          relativePath,
          'root must be a JSON object, got ${decoded.runtimeType}',
        ),
      ],
      pack: null,
    );
  }
  final issues = _validatePackObject(
    decoded,
    relativePath: relativePath,
    strictReview: strictReview,
  );
  return (
    issues: issues,
    pack: ParsedPack(relativePath: relativePath, json: decoded),
  );
}

List<PackIssue> _validatePackObject(
  Map<String, dynamic> json, {
  required String relativePath,
  required bool strictReview,
}) {
  final issues = <PackIssue>[];
  void error(String message) =>
      issues.add(PackIssue(IssueSeverity.error, relativePath, message));
  void warn(String message) =>
      issues.add(PackIssue(IssueSeverity.warning, relativePath, message));

  // additionalProperties: false (root).
  const allowedPackFields = [...requiredPackFields, ...optionalPackFields];
  for (final key in json.keys) {
    if (!allowedPackFields.contains(key)) {
      error('unknown field "$key" (schema: additionalProperties false)');
    }
  }
  for (final key in requiredPackFields) {
    if (!json.containsKey(key)) {
      error('missing required field "$key"');
    }
  }

  // packId: string, ^[a-z0-9_]+$.
  final rawPackId = json['packId'];
  String? packId;
  if (json.containsKey('packId')) {
    if (rawPackId is! String || rawPackId.isEmpty) {
      error('"packId" must be a non-empty string');
    } else if (!idPattern.hasMatch(rawPackId)) {
      error('"packId" "$rawPackId" does not match pattern ^[a-z0-9_]+\$');
    } else {
      packId = rawPackId;
    }
  }

  // version: integer >= 1. In Dart's JSON, 1.0 decodes as double — reject
  // any non-int so the wire stays integer-typed.
  final rawVersion = json['version'];
  if (json.containsKey('version')) {
    if (rawVersion is! int) {
      error('"version" must be an integer, got ${rawVersion.runtimeType}');
    } else if (rawVersion < 1) {
      error('"version" must be >= 1, got $rawVersion');
    }
  }

  // locale: enum.
  final rawLocale = json['locale'];
  String? locale;
  if (json.containsKey('locale')) {
    if (rawLocale is! String || !knownLocales.contains(rawLocale)) {
      error(
        '"locale" must be one of $knownLocales, got ${jsonEncode(rawLocale)}',
      );
    } else {
      locale = rawLocale;
    }
  }

  // register: enum.
  final rawRegister = json['register'];
  if (json.containsKey('register') &&
      (rawRegister is! String || !knownRegisters.contains(rawRegister))) {
    error(
      '"register" must be one of $knownRegisters, '
      'got ${jsonEncode(rawRegister)}',
    );
  }

  // reviewedBy: string when present; shippability flag (W9) when absent or
  // still carrying a PENDING/NONE placeholder.
  final rawReviewedBy = json['reviewedBy'];
  if (json.containsKey('reviewedBy') && rawReviewedBy is! String) {
    error('"reviewedBy" must be a string, got ${rawReviewedBy.runtimeType}');
  } else {
    final reviewedBy = rawReviewedBy as String?;
    final unreviewed =
        reviewedBy == null ||
        reviewedBy.isEmpty ||
        reviewedBy.startsWith('PENDING') ||
        reviewedBy.startsWith('NONE');
    if (unreviewed) {
      final message =
          'reviewedBy is ${reviewedBy == null ? 'missing' : jsonEncode(reviewedBy)}'
          ' — native register-owner review is mandatory before public launch '
          '(W9, ADR-007)';
      strictReview ? error(message) : warn(message);
    }
  }

  // packId ↔ filename: basename must be "<packId>.json".
  final basename = relativePath.split('/').last;
  if (packId != null && basename != '$packId.json') {
    error(
      'filename "$basename" must be "<packId>.json" ("$packId.json") — '
      'packId↔filename consistency',
    );
  }

  // packId ↔ locale: the locale must appear as an underscore-delimited
  // segment of the packId (solo_tr → tr; ar_msa_gulf → ar; en → en).
  if (packId != null && locale != null && !packId.split('_').contains(locale)) {
    error(
      'packId "$packId" does not carry its locale "$locale" as an '
      'underscore-delimited segment — packId↔locale consistency',
    );
  }

  // questions: non-empty array of valid question objects, ids unique in-pack.
  final rawQuestions = json['questions'];
  if (json.containsKey('questions')) {
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      error('"questions" must be a non-empty array (schema: minItems 1)');
    } else {
      final seenIds = <String>{};
      for (var i = 0; i < rawQuestions.length; i++) {
        final raw = rawQuestions[i];
        if (raw is! Map<String, dynamic>) {
          error('questions[$i] must be an object, got ${raw.runtimeType}');
          continue;
        }
        issues.addAll(
          _validateQuestion(raw, index: i, relativePath: relativePath),
        );
        final id = raw['id'];
        if (id is String && idPattern.hasMatch(id) && !seenIds.add(id)) {
          error('questions[$i]: duplicate question id "$id" within the pack');
        }
      }
    }
  }

  return issues;
}

List<PackIssue> _validateQuestion(
  Map<String, dynamic> json, {
  required int index,
  required String relativePath,
}) {
  final issues = <PackIssue>[];
  final id = json['id'] is String ? json['id'] as String : null;
  final where = '$relativePath: questions[$index]${id == null ? '' : ' "$id"'}';
  void error(String message) =>
      issues.add(PackIssue(IssueSeverity.error, where, message));

  const allowedFields = [...requiredQuestionFields, ...optionalQuestionFields];
  for (final key in json.keys) {
    if (!allowedFields.contains(key)) {
      error('unknown field "$key" (schema: additionalProperties false)');
    }
  }
  for (final key in requiredQuestionFields) {
    if (!json.containsKey(key)) {
      error('missing required field "$key"');
    }
  }

  final rawId = json['id'];
  if (json.containsKey('id')) {
    if (rawId is! String || rawId.isEmpty) {
      error('"id" must be a non-empty string');
    } else if (!idPattern.hasMatch(rawId)) {
      error('"id" "$rawId" does not match pattern ^[a-z0-9_]+\$');
    }
  }

  final rawCategory = json['category'];
  if (json.containsKey('category') &&
      (rawCategory is! String || !knownCategories.contains(rawCategory))) {
    error(
      '"category" must be one of $knownCategories, '
      'got ${jsonEncode(rawCategory)}',
    );
  }

  final rawDepth = json['depth'];
  if (json.containsKey('depth')) {
    if (rawDepth is! int) {
      error('"depth" must be an integer, got ${rawDepth.runtimeType}');
    } else if (rawDepth < minDepth || rawDepth > maxDepth) {
      error('"depth" must be $minDepth-$maxDepth, got $rawDepth');
    }
  }

  final rawText = json['text'];
  if (json.containsKey('text') && (rawText is! String || rawText.isEmpty)) {
    error('"text" must be a non-empty string (schema: minLength 1)');
  }

  final rawWindow = json['seasonalWindow'];
  if (json.containsKey('seasonalWindow') &&
      (rawWindow is! String || rawWindow.isEmpty)) {
    error('"seasonalWindow" must be a non-empty string when present');
  }

  return issues;
}

/// Cross-pack checks over every successfully parsed pack: question-id
/// uniqueness ACROSS packs and packId uniqueness (two files must not claim
/// the same pack).
List<PackIssue> validateAcrossPacks(List<ParsedPack> packs) {
  final issues = <PackIssue>[];
  final packIdOwner = <String, String>{};
  final questionIdOwner = <String, String>{};

  for (final pack in packs) {
    final packId = pack.packId;
    if (packId.isNotEmpty) {
      final owner = packIdOwner[packId];
      if (owner != null) {
        issues.add(
          PackIssue(
            IssueSeverity.error,
            pack.relativePath,
            'duplicate packId "$packId" (also declared by $owner)',
          ),
        );
      } else {
        packIdOwner[packId] = pack.relativePath;
      }
    }

    final rawQuestions = pack.json['questions'];
    if (rawQuestions is! List) continue;
    for (final raw in rawQuestions) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id'];
      if (id is! String || id.isEmpty) continue;
      final owner = questionIdOwner[id];
      // Same-pack duplicates are already reported field-precisely by
      // validatePackSource; only cross-file collisions are new information.
      if (owner != null && owner != pack.relativePath) {
        issues.add(
          PackIssue(
            IssueSeverity.error,
            pack.relativePath,
            'question id "$id" duplicates one in $owner — question ids must '
            'be unique across packs',
          ),
        );
      } else {
        questionIdOwner[id] = pack.relativePath;
      }
    }
  }
  return issues;
}

/// Guards the hand-rolled core against silent drift from the JSON Schema
/// file: [schemaSource] is `content/schema/question-pack.schema.json`, and
/// every vocabulary/bound the core enforces must match it exactly.
List<PackIssue> validateSchemaAgreement(String schemaSource) {
  const where = 'content/schema/question-pack.schema.json';
  final issues = <PackIssue>[];
  void error(String message) =>
      issues.add(PackIssue(IssueSeverity.error, where, message));

  final Object? decoded;
  try {
    decoded = jsonDecode(schemaSource);
  } on FormatException catch (e) {
    return [
      PackIssue(IssueSeverity.error, where, 'invalid JSON: ${e.message}'),
    ];
  }
  if (decoded is! Map<String, dynamic>) {
    return [
      PackIssue(IssueSeverity.error, where, 'root must be a JSON object'),
    ];
  }

  final props = decoded['properties'];
  final questionSchema = props is Map<String, dynamic>
      ? ((props['questions'] as Map<String, dynamic>?)?['items'])
      : null;
  final questionProps = questionSchema is Map<String, dynamic>
      ? questionSchema['properties']
      : null;

  List<String>? stringList(Object? raw) =>
      raw is List && raw.every((e) => e is String) ? raw.cast<String>() : null;

  void checkEnum(String field, Object? schemaNode, List<String> coreValues) {
    final values = schemaNode is Map<String, dynamic>
        ? stringList(schemaNode['enum'])
        : null;
    if (values == null || !_sameList(values, coreValues)) {
      error(
        'schema "$field" enum ${values ?? '(missing)'} != validator '
        '$coreValues — update both together',
      );
    }
  }

  if (props is! Map<String, dynamic> ||
      questionProps is! Map<String, dynamic>) {
    error(
      'schema shape changed: properties/questions.items.properties '
      'not found — update the validator with it',
    );
    return issues;
  }

  checkEnum('locale', props['locale'], knownLocales);
  checkEnum('register', props['register'], knownRegisters);
  checkEnum(
    'questions.items.category',
    questionProps['category'],
    knownCategories,
  );

  final required = stringList(decoded['required']);
  if (required == null || !_sameList(required, requiredPackFields)) {
    error(
      'schema required ${required ?? '(missing)'} != validator '
      '$requiredPackFields — update both together',
    );
  }
  final questionRequired = stringList(questionSchema['required']);
  if (questionRequired == null ||
      !_sameList(questionRequired, requiredQuestionFields)) {
    error(
      'schema questions.items.required ${questionRequired ?? '(missing)'} != '
      'validator $requiredQuestionFields — update both together',
    );
  }

  final packFieldNames = props.keys.toList();
  const corePackFields = [...requiredPackFields, ...optionalPackFields];
  if (!_sameSet(packFieldNames, corePackFields)) {
    error(
      'schema pack fields $packFieldNames != validator $corePackFields — '
      'update both together',
    );
  }
  final questionFieldNames = questionProps.keys.toList();
  const coreQuestionFields = [
    ...requiredQuestionFields,
    ...optionalQuestionFields,
  ];
  if (!_sameSet(questionFieldNames, coreQuestionFields)) {
    error(
      'schema question fields $questionFieldNames != validator '
      '$coreQuestionFields — update both together',
    );
  }

  final depth = questionProps['depth'];
  final depthMin = depth is Map<String, dynamic> ? depth['minimum'] : null;
  final depthMax = depth is Map<String, dynamic> ? depth['maximum'] : null;
  if (depthMin != minDepth || depthMax != maxDepth) {
    error(
      'schema depth bounds [$depthMin, $depthMax] != validator '
      '[$minDepth, $maxDepth] — update both together',
    );
  }

  return issues;
}

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

bool _sameSet(List<String> a, List<String> b) =>
    a.toSet().containsAll(b) && b.toSet().containsAll(a);
