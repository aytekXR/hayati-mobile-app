import '../domain/solo_answer.dart';

/// Wire mapping for `users/{uid}/soloAnswers/{yyyymmdd}` (M2.4). Pure
/// function over a plain map — the repository converts the wire `Timestamp`
/// to a [DateTime] BEFORE calling in (same boundary discipline as
/// `profileFromMap`), so no Firestore type crosses into the domain.
///
/// There is deliberately no `soloAnswerToMap`: the write shape lives in the
/// repository because `answeredAt` is a `FieldValue.serverTimestamp()`
/// sentinel (rules-enforced `== request.time`), which a pure mapper must not
/// know about.
SoloAnswer soloAnswerFromMap(Map<String, dynamic> data) => SoloAnswer(
  questionId: _stringField(data, 'questionId'),
  text: _stringField(data, 'text'),
  answeredAt: _optionalDateTime(data, 'answeredAt'),
);

String _stringField(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw is! String) {
    throw FormatException(
      'soloAnswers doc field "$field": expected a string, '
      'got ${raw.runtimeType}',
    );
  }
  return raw;
}

/// Null is legitimate: the local echo of an unacked write carries a pending
/// server timestamp. Anything else non-DateTime is a missed boundary
/// conversion and fails loudly.
DateTime? _optionalDateTime(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return null;
  if (raw is! DateTime) {
    throw FormatException(
      'soloAnswers doc field "$field": expected a DateTime, '
      'got ${raw.runtimeType}',
    );
  }
  return raw;
}
