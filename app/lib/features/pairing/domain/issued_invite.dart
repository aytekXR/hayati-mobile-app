/// A one-active-invite result issued by the `createInvite` callable (M2.1):
/// the shareable [code], when it lapses ([expiresAt], 48h TTL server-set), and
/// whether the caller's existing pending invite was [reused] (idempotent
/// re-issue) rather than freshly minted. Pure Dart — the wire shape
/// (`expiresAtMillis`) is mapped at the data boundary, never here.
class IssuedInvite {
  const IssuedInvite({
    required this.code,
    required this.expiresAt,
    required this.reused,
  });

  final String code;
  final DateTime expiresAt;
  final bool reused;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssuedInvite &&
          other.code == code &&
          other.expiresAt == expiresAt &&
          other.reused == reused;

  @override
  int get hashCode => Object.hash(code, expiresAt, reused);

  @override
  String toString() =>
      'IssuedInvite(code: $code, expiresAt: $expiresAt, reused: $reused)';
}
