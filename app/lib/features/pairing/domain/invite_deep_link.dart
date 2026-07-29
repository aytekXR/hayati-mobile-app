import 'normalize_invite_code.dart';

/// The custom domain the invite site is INTENDED to live on (ADR-036).
///
/// Not yet reachable: `ikimiz.beyondkaira.com` still resolves to the founder's
/// own VPS, whose TLS certificate covers the apex only, so an invitee tapping a
/// link on this host today gets a browser security interstitial — a red warning
/// screen — before they get anything else. It stays a first-class PARSED host
/// (see [kInviteLinkHosts]) so every link already sent keeps working the moment
/// the DNS record moves, and so flipping [kInviteLinkUsesCustomDomain] is the
/// only change that will be needed then.
const String kInviteLinkCustomHost = 'ikimiz.beyondkaira.com';

/// Firebase Hosting's default domain for the SAME site (`site: ikimiz` in
/// `firebase.json`), which means the same content, the same
/// `apple-app-site-association` and the same `/i/**` rewrite.
///
/// It is the host invites are built on today, for one reason: it works. TLS is
/// issued and renewed by Google, it needs no DNS record from anybody, and it is
/// live the moment `deploy-site.yml` publishes — whereas the custom domain needs
/// a registrar change only the founder can make (operator-expected 2(e)(i)).
/// A working link on a plainer host converts an invite; a prettier host that
/// throws a certificate warning does not.
const String kInviteLinkHostingHost = 'ikimiz.web.app';

/// Firebase Hosting's OTHER default domain for the same site. Never emitted —
/// it is only ever accepted, because Hosting serves both and a link that reaches
/// a partner by any route at all must open the app.
const String kInviteLinkHostingAltHost = 'ikimiz.firebaseapp.com';

/// Which host newly-issued links are BUILT on. **This is the one line to change
/// when the DNS record for [kInviteLinkCustomHost] finally points at Firebase**
/// (verify with `curl -sI https://ikimiz.beyondkaira.com/i/TESTTEST` first — a
/// 200 rather than a certificate error). Nothing else moves: every host below is
/// already parsed, so old and new links coexist by construction.
const bool kInviteLinkUsesCustomDomain = false;

/// The host [inviteLinkFor] emits.
const String kInviteLinkHost = kInviteLinkUsesCustomDomain
    ? kInviteLinkCustomHost
    : kInviteLinkHostingHost;

/// Every host an invite link may arrive on, lowercase.
///
/// Deliberately a CLOSED set, and the security property of this whole file: any
/// site on the internet can serve the `/i/<code>` path shape, so membership here
/// — not the path — is what makes a URL an invite. Each entry is a host this
/// project controls and serves the invite site from.
const Set<String> kInviteLinkHosts = {
  kInviteLinkCustomHost,
  kInviteLinkHostingHost,
  kInviteLinkHostingAltHost,
};

/// The path prefix under every host in [kInviteLinkHosts]. Short because it gets
/// typed and re-typed by hand in messaging apps.
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
/// TWO FORMS are accepted, on purpose:
///
///  * `https://<host>/i/<code>` for any host in [kInviteLinkHosts] — the
///    universal link (ADR-036). It is clickable in WhatsApp, survives
///    copy-paste, and degrades to a real web page when the app is not installed,
///    which the custom scheme never did. Several hosts are accepted rather than
///    one because the site is reachable under several names and the app must
///    never be the reason a link that a partner actually received fails to open
///    it — including a link sent before or after the custom domain goes live.
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
    if (!kInviteLinkHosts.contains(uri.host.toLowerCase())) return null;
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
