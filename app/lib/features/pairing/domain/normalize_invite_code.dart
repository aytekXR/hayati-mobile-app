/// Invite-code shape: 8 characters from the 31-symbol alphabet (uppercase
/// A–Z + digits 2–9 minus the ambiguous 0/O/1/I/L). This regex must stay in
/// lockstep with the generator — the single source of truth is
/// functions/src/invites/invite-code.ts (`INVITE_CODE_ALPHABET`, length 8).
final RegExp _inviteCodePattern = RegExp(r'^[A-HJ-KM-NP-Z2-9]{8}$');

/// Canonicalizes a raw invite code the way the server's normalizer does
/// (`functions/src/invites/invite-code.ts` → trim + uppercase + alphabet
/// check): returns the 8-char canonical code, or null when [raw] is not a
/// well-formed code (empty, wrong length, or an ambiguous/out-of-alphabet
/// character). Pure — the single client-side source of truth shared by manual
/// code entry (M2.3) and deep-link parsing ([inviteCodeFromUri]), so both the
/// join flow and cold-start parsing validate identically and in isolation.
String? normalizeInviteCode(String raw) {
  final normalized = raw.trim().toUpperCase();
  return _inviteCodePattern.hasMatch(normalized) ? normalized : null;
}
