import 'normalize_invite_code.dart';

/// The public host that serves invite links (ADR-036). Universal links land on
/// `https://ikimiz.beyondkaira.com/i/<code>`; that page only ever renders for
/// someone who does NOT have the app, because iOS claims the path via the
/// `apple-app-site-association` file served from the same host.
const String kInviteLinkHost = 'ikimiz.beyondkaira.com';

/// The path prefix under [kInviteLinkHost]. Short because it gets typed and
/// re-typed by hand in messaging apps.
const String kInviteLinkPathPrefix = 'i';

/// Builds the shareable invite link for [code].
///
/// ONE constructor, so the string in the share sheet, the string the parser
/// accepts, and the string the tests assert cannot drift apart — the share
/// screen used to build this inline.
String inviteLinkFor(String code) =>
    'https://$kInviteLinkHost/$kInviteLinkPathPrefix/$code';

/// Extracts the invite code from an invite deep link, or null when [uri] is not
/// a well-formed one.
///
/// TWO forms are accepted, on purpose:
///
///  * `https://ikimiz.beyondkaira.com/i/<code>` — the universal link that ships
///    now (ADR-036). It is clickable in WhatsApp, survives copy-paste, and
///    degrades to a real web page when the app is not installed, which the
///    custom scheme never did.
///  * `hayati://invite/<code>` — the ORIGINAL custom scheme. Kept because links
///    already sent to a partner sit in someone's chat history forever, and the
///    person following a months-old invite is exactly the person least able to
///    work out why nothing happened. The scheme keeps the old name because it
///    is a registered identifier, not customer-facing text (ADR-035 D5), and
///    renaming it would break the very links this branch exists to honour.
///
/// In both forms the code segment goes through [normalizeInviteCode] (trim +
/// uppercase + alphabet check — the shared single source of truth) and a query
/// string is ignored. Anything else — wrong scheme/host/prefix, wrong segment
/// count, a code with ambiguous characters or the wrong length — returns null.
/// Pure: no plugin or platform dependency, so the join flow (M2.3) and
/// cold-start parsing stay unit-testable in isolation.
String? inviteCodeFromUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();

  if (scheme == 'https') {
    if (uri.host.toLowerCase() != kInviteLinkHost) return null;
    final segments = uri.pathSegments;
    if (segments.length != 2) return null;
    if (segments.first.toLowerCase() != kInviteLinkPathPrefix) return null;
    return normalizeInviteCode(segments.last);
  }

  // Legacy custom scheme, still honoured for links already in the wild.
  if (scheme != 'hayati') return null;
  if (uri.host.toLowerCase() != 'invite') return null;
  if (uri.pathSegments.length != 1) return null;
  return normalizeInviteCode(uri.pathSegments.single);
}
