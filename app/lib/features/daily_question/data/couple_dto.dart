import '../domain/couple.dart';

/// Wire mapping for `couples/{coupleId}` (M3.3). Pure function over a plain
/// map plus the externally-known doc id — same boundary discipline as
/// `profileFromMap`: junk shapes fail loudly, no Firestore type crosses in.
Couple coupleFromMap(String id, Map<String, dynamic> data) {
  final rawUids = data['memberUids'];
  if (rawUids is! List || rawUids.length != 2) {
    throw FormatException(
      'couples doc field "memberUids": expected a 2-element list, '
      'got ${rawUids.runtimeType}'
      '${rawUids is List ? ' of length ${rawUids.length}' : ''}',
    );
  }
  final memberUids = <String>[];
  for (final raw in rawUids) {
    if (raw is! String || raw.isEmpty) {
      throw FormatException(
        'couples doc field "memberUids": expected non-empty strings, '
        'got ${raw.runtimeType}',
      );
    }
    memberUids.add(raw);
  }
  final timezone = data['timezone'];
  if (timezone is! String || timezone.isEmpty) {
    throw FormatException(
      'couples doc field "timezone": expected a non-empty string, '
      'got ${timezone.runtimeType}',
    );
  }
  return Couple(id: id, memberUids: memberUids, timezone: timezone);
}
