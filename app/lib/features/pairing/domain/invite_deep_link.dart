/// Invite-code shape: 8 characters from the 31-symbol alphabet (uppercase
/// A–Z + digits 2–9 minus the ambiguous 0/O/1/I/L). This regex must stay in
/// lockstep with the generator — the single source of truth is
/// functions/src/invites/invite-code.ts (`INVITE_CODE_ALPHABET`, length 8).
final RegExp _inviteCodePattern = RegExp(r'^[A-HJ-KM-NP-Z2-9]{8}$');

/// Extracts the invite code from a `hayati://invite/<code>` deep link, or null
/// when [uri] is not a well-formed invite link.
///
/// Accepts scheme `hayati` and host `invite` (both case-insensitive, already
/// normalised to lowercase by [Uri]) with exactly one path segment. The
/// segment is trimmed and uppercased, then validated against the invite-code
/// alphabet; a query string is ignored. Anything else — wrong scheme/host,
/// zero or multiple segments, a code with ambiguous characters or the wrong
/// length — returns null. Pure: no plugin or platform dependency, so the join
/// flow (M2.3) and cold-start parsing are unit-testable in isolation.
String? inviteCodeFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'hayati') return null;
  if (uri.host.toLowerCase() != 'invite') return null;
  if (uri.pathSegments.length != 1) return null;
  final code = uri.pathSegments.single.trim().toUpperCase();
  return _inviteCodePattern.hasMatch(code) ? code : null;
}
