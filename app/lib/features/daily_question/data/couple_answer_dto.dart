import '../domain/couple_answer.dart';

/// Wire mapping for `couples/{cid}/days/{dayKey}/answers/{authorUid}`
/// (M3.3). Pure function over a plain map — the repository converts the wire
/// `Timestamp` to a [DateTime] BEFORE calling in, mirroring
/// `soloAnswerFromMap`.
///
/// There is deliberately no `coupleAnswerToMap`: the write shape lives in
/// the repository because `answeredAt` is a `FieldValue.serverTimestamp()`
/// sentinel (rules-enforced `== request.time`), which a pure mapper must
/// not know about.
CoupleAnswer coupleAnswerFromMap(Map<String, dynamic> data) => CoupleAnswer(
  questionId: _stringField(data, 'questionId'),
  text: _stringField(data, 'text'),
  answeredAt: _optionalDateTime(data, 'answeredAt'),
);

String _stringField(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw is! String) {
    throw FormatException(
      'answers doc field "$field": expected a string, got ${raw.runtimeType}',
    );
  }
  return raw;
}

/// Null is legitimate: the local echo of an unacked write carries a pending
/// server timestamp — and the partner-slot gate keys off exactly this null.
DateTime? _optionalDateTime(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return null;
  if (raw is! DateTime) {
    throw FormatException(
      'answers doc field "$field": expected a DateTime, got ${raw.runtimeType}',
    );
  }
  return raw;
}
