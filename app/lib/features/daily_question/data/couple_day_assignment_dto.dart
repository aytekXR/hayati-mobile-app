import '../domain/couple_day_assignment.dart';

/// Wire mapping for `couples/{cid}/days/{yyyymmdd}` (M3.3). Pure function
/// over a plain map — the repository converts the wire `Timestamp` to a
/// [DateTime] BEFORE calling in (same boundary discipline as
/// `soloAnswerFromMap`). The rollover writes this shape exclusively, so a
/// junk field here is corrupt state and fails loudly.
CoupleDayAssignment coupleDayAssignmentFromMap(Map<String, dynamic> data) =>
    CoupleDayAssignment(
      questionId: _stringField(data, 'questionId'),
      packId: _stringField(data, 'packId'),
      packVersion: _intField(data, 'packVersion'),
      assignedAt: _optionalDateTime(data, 'assignedAt'),
    );

String _stringField(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw is! String || raw.isEmpty) {
    throw FormatException(
      'days doc field "$field": expected a non-empty string, '
      'got ${raw.runtimeType}',
    );
  }
  return raw;
}

int _intField(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw is! int) {
    throw FormatException(
      'days doc field "$field": expected an int, got ${raw.runtimeType}',
    );
  }
  return raw;
}

DateTime? _optionalDateTime(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return null;
  if (raw is! DateTime) {
    throw FormatException(
      'days doc field "$field": expected a DateTime, got ${raw.runtimeType}',
    );
  }
  return raw;
}
