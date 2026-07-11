/// The couple's mutual-day streak record (M3.4, ADR-012 Decision 2). Like the
/// rest of [Couple], this is SERVER-OWNED read-only truth: it is written ONLY
/// by the reveal trigger's transaction (`handleAnswerCreated`) and rules-frozen
/// against clients — the M3.3 `timezone`/`createdAt` freeze pattern extended to
/// `streak`, with symmetric absence handling (the field does not exist until
/// the couple's first mutual day). The wire shape on `couples/{cid}` is
/// `streak {count, lastMutualDate, graceTokens}`; an ABSENT field reads as
/// [zero] (ADR-012 — no migration, no join-Function change).
class CoupleStreak {
  const CoupleStreak({
    required this.count,
    required this.lastMutualDate,
    required this.graceTokens,
  });

  /// The zero state, mirroring the Functions `INITIAL_STREAK` (ADR-012
  /// Decision 2): no mutual day yet, one mercy token in hand. This is both the
  /// value an ABSENT wire `streak` maps to and [Couple.streak]'s default, so
  /// the two sides can never disagree on "brand-new couple".
  static const zero = CoupleStreak(
    count: 0,
    lastMutualDate: null,
    graceTokens: 1,
  );

  /// Consecutive couple-local mutual days (ADR-012 — pure Gregorian calendar
  /// math over dayKeys). 0 = no mutual day yet; the paired home renders NOTHING
  /// at 0 (honest display — reveal-trigger lag or a not-yet-deployed trigger
  /// must never surface as a real zero-day streak).
  final int count;

  /// The `yyyymmdd` dayKey of the last mutual day (couple-local calendar,
  /// ADR-011), or null before the first one. The server only ever moves it
  /// forward (`max(prev, dayKey)`); the client never writes it.
  final String? lastMutualDate;

  /// Remaining mercy tokens (PRD F3 "one free mercy day per week"): refilled to
  /// 1 on ISO-week entry, consumed to bridge exactly one missed day (ADR-012).
  final int graceTokens;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleStreak &&
          other.count == count &&
          other.lastMutualDate == lastMutualDate &&
          other.graceTokens == graceTokens;

  @override
  int get hashCode => Object.hash(count, lastMutualDate, graceTokens);

  @override
  String toString() =>
      'CoupleStreak(count: $count, lastMutualDate: $lastMutualDate, '
      'graceTokens: $graceTokens)';
}

/// The couple aggregate root read model (M3.3 — the app's first
/// `couples/{coupleId}` read, docs/architecture.md §3). Server-owned: the
/// M2.3 join Function creates it, rules freeze `memberUids`, `timezone`,
/// `createdAt`, and (M3.4) `streak` against clients, so every field here is
/// read-only truth. Pure Dart; `packConfig` stays unmapped until W9 needs it.
class Couple {
  const Couple({
    required this.id,
    required this.memberUids,
    required this.timezone,
    this.streak = CoupleStreak.zero,
  });

  final String id;

  /// Exactly two uids, creator first (M2.3 contract, rules-frozen).
  final List<String> memberUids;

  /// IANA zone id, allow-listed at join and rules-frozen since M3.3 — the
  /// single input to [coupleDayKey] (ADR-011: the couple dayKey is a pure
  /// function of THIS zone, never the device zone).
  final String timezone;

  /// The mutual-day streak (M3.4, ADR-012). Defaults to [CoupleStreak.zero],
  /// which is also how an absent wire `streak` maps — a brand-new couple and a
  /// couple whose streak field simply has not been written yet are the same
  /// read model, honestly.
  final CoupleStreak streak;

  /// The other member's uid, or null if [ownUid] is not a member (corrupt
  /// state — a `users.coupleId` pointing at a foreign couple; callers
  /// surface it as an error, never guess).
  String? partnerUidFor(String ownUid) {
    if (!memberUids.contains(ownUid)) return null;
    for (final uid in memberUids) {
      if (uid != ownUid) return uid;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Couple &&
          other.id == id &&
          other.timezone == timezone &&
          other.streak == streak &&
          other.memberUids.length == memberUids.length &&
          _sameUids(other.memberUids);

  bool _sameUids(List<String> otherUids) {
    for (var i = 0; i < memberUids.length; i++) {
      if (memberUids[i] != otherUids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(id, timezone, streak, Object.hashAll(memberUids));

  @override
  String toString() =>
      'Couple(id: $id, memberUids: $memberUids, timezone: $timezone, '
      'streak: $streak)';
}
