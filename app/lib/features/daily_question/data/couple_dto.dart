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
  return Couple(
    id: id,
    memberUids: memberUids,
    timezone: timezone,
    streak: _streakFromMap(data['streak']),
  );
}

/// Maps the server-owned `streak {count, lastMutualDate, graceTokens}` submap
/// (M3.4, ADR-012). ABSENT → [CoupleStreak.zero] (the field does not exist
/// until the couple's first mutual day — a brand-new couple reads as zero, no
/// migration). PRESENT but malformed → a loud [FormatException] naming the
/// exact subfield, same discipline as the top-level couple fields.
///
/// A present submap must carry all three fields: the reveal trigger writes them
/// atomically (ADR-012 Decision 1), so a positive-streak record missing its
/// `lastMutualDate` is corrupt state, not the zero case — we throw rather than
/// fabricate a null date that would silently drift the (server-side) streak
/// arithmetic. `null` (absent) is the ONLY path to a null `lastMutualDate`.
CoupleStreak _streakFromMap(Object? raw) {
  if (raw == null) return CoupleStreak.zero;
  if (raw is! Map) {
    throw FormatException(
      'couples doc field "streak": expected a map, got ${raw.runtimeType}',
    );
  }
  final count = raw['count'];
  if (count is! int || count < 0) {
    throw FormatException(
      'couples doc field "streak.count": expected a non-negative int, '
      'got ${count.runtimeType}',
    );
  }
  final graceTokens = raw['graceTokens'];
  if (graceTokens is! int || graceTokens < 0) {
    throw FormatException(
      'couples doc field "streak.graceTokens": expected a non-negative int, '
      'got ${graceTokens.runtimeType}',
    );
  }
  final lastMutualDate = raw['lastMutualDate'];
  if (lastMutualDate is! String || lastMutualDate.isEmpty) {
    throw FormatException(
      'couples doc field "streak.lastMutualDate": expected a non-empty '
      'yyyymmdd string, got ${lastMutualDate.runtimeType}',
    );
  }
  return CoupleStreak(
    count: count,
    lastMutualDate: lastMutualDate,
    graceTokens: graceTokens,
  );
}
