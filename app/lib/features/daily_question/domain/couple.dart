/// The couple aggregate root read model (M3.3 — the app's first
/// `couples/{coupleId}` read, docs/architecture.md §3). Server-owned: the
/// M2.3 join Function creates it, rules freeze `memberUids`, `timezone`,
/// and `createdAt` against clients, so every field here is read-only truth.
/// Pure Dart; `packConfig`/`streak` stay unmapped until a milestone needs
/// them (W9 / M3.4).
class Couple {
  const Couple({
    required this.id,
    required this.memberUids,
    required this.timezone,
  });

  final String id;

  /// Exactly two uids, creator first (M2.3 contract, rules-frozen).
  final List<String> memberUids;

  /// IANA zone id, allow-listed at join and rules-frozen since M3.3 — the
  /// single input to [coupleDayKey] (ADR-011: the couple dayKey is a pure
  /// function of THIS zone, never the device zone).
  final String timezone;

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
          other.memberUids.length == memberUids.length &&
          _sameUids(other.memberUids);

  bool _sameUids(List<String> otherUids) {
    for (var i = 0; i < memberUids.length; i++) {
      if (memberUids[i] != otherUids[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, timezone, Object.hashAll(memberUids));

  @override
  String toString() =>
      'Couple(id: $id, memberUids: $memberUids, timezone: $timezone)';
}
