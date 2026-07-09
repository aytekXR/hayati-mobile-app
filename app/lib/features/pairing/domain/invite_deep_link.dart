import 'normalize_invite_code.dart';

/// Extracts the invite code from a `hayati://invite/<code>` deep link, or null
/// when [uri] is not a well-formed invite link.
///
/// Accepts scheme `hayati` and host `invite` (both case-insensitive, already
/// normalised to lowercase by [Uri]) with exactly one path segment. The
/// segment is handed to [normalizeInviteCode] (trim + uppercase + alphabet
/// check — the shared single source of truth); a query string is ignored.
/// Anything else — wrong scheme/host, zero or multiple segments, a code with
/// ambiguous characters or the wrong length — returns null. Pure: no plugin or
/// platform dependency, so the join flow (M2.3) and cold-start parsing are
/// unit-testable in isolation.
String? inviteCodeFromUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'hayati') return null;
  if (uri.host.toLowerCase() != 'invite') return null;
  if (uri.pathSegments.length != 1) return null;
  return normalizeInviteCode(uri.pathSegments.single);
}
