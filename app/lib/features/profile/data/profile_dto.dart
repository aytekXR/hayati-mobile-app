import '../domain/relationship_profile.dart';

/// Wire mapping for `users/{uid}` (docs/architecture.md §3). Pure functions
/// over plain maps — no Firestore types cross into the domain, and the
/// mapper is fully unit-testable in the plain test VM.
///
/// Enum wire names are the Dart `name`s and are load-bearing once written:
/// renaming an enum member is a data migration, not a refactor.
///
/// [coupleId] crosses READ-ONLY at M2.3 (the join flow stamps it server-side):
/// absent → null, present non-string → [FormatException] (same loud discipline
/// as the enums — a corrupt pairing is a visible failure, not silently lost).
/// It is deliberately NOT round-tripped by [profileToMap].
///
/// [createdAt] crosses READ-ONLY at M2.4 (the solo day-N anchor). To keep this
/// mapper pure the repository converts the wire `Timestamp` to a [DateTime]
/// BEFORE calling in; a still-`Timestamp` value here is therefore a missed
/// boundary conversion and fails loudly. Null is legitimate: the local echo of
/// the very first save carries a pending server timestamp.
/// [notificationPrivacy] crosses READ-ONLY at M6.2 (ADR-019 D6): an enum-safe
/// defensive read where only the exact string `'discreet'` counts — absent or any
/// junk value reads false, never throws (a display/settings toggle must not brick
/// the profile stream on a stray value). Never round-tripped by [profileToMap].
///
/// [coupleEndedAt] crosses READ-ONLY at M6.2 (ADR-019 D3) from the NESTED
/// `coupleEnded: { at: Timestamp }` map. Like [createdAt], the repository converts
/// the wire `Timestamp` to a [DateTime] at the Firestore boundary BEFORE calling
/// in (keeping this mapper pure); a still-`Timestamp` inner value here is a missed
/// boundary conversion and fails loudly. Absent `coupleEnded` → null.
RelationshipProfile profileFromMap(Map<String, dynamic> data) =>
    RelationshipProfile(
      status: _enumField(data, 'status', RelationshipStatus.values),
      contentLanguage: _enumField(
        data,
        'contentLanguage',
        ContentLanguage.values,
      ),
      register: _enumField(data, 'register', ContentRegister.values),
      coupleId: _optionalString(data, 'coupleId'),
      createdAt: _optionalDateTime(data, 'createdAt'),
      notificationPrivacyDiscreet: data['notificationPrivacy'] == 'discreet',
      coupleEndedAt: _nestedDateTime(data, 'coupleEnded', 'at'),
      consent: _consentField(data),
    );

/// Client-owned fields only: server-owned fields (createdAt, coupleId, consent,
/// fcmTokens — future milestones) are managed by the repository/Functions
/// and must never be emitted from here — [coupleId] is read back but NEVER
/// written, so a profile edit merges without touching the server's pairing.
/// [Consent] is likewise READ-ONLY: omitting it here is load-bearing — the
/// users-doc update rule FREEZES `consent`, so a merge-write that DID emit it
/// would be denied (ADR-023 D4). Typed `Map<String, dynamic>` to match
/// Firestore's API surface exactly (keeps `set<T>` inference stable).
Map<String, dynamic> profileToMap(RelationshipProfile profile) => {
  'status': profile.status.name,
  'contentLanguage': profile.contentLanguage.name,
  'register': profile.register.name,
};

/// Parses the server-owned `consent` map (ADR-023 D4) JUNK-SAFELY — the
/// deliberate departure from the loud [_enumField] / [_optionalDateTime] style:
/// consent must fail CLOSED (a junk shape reads as ABSENT ⇒ `hasCurrentConsent`
/// is false ⇒ the gate shows and the user re-consents), never THROW (a throw
/// hits the gate's `_GateErrorView`, which would let a corrupt consent field
/// brick the whole profile stream on a spinner/retry — the wrong failure mode).
///
/// The matrix, pinned by the malformed-shape test and mutation-checked:
///  - absent, or non-map                       → null (absent);
///  - `version` missing, or not an int         → null (absent);
///  - int `version`, `acceptedAt` MISSING      → present, acceptedAt null
///    (the status line degrades to version-only; [Consent.acceptedAt] is
///    nullable exactly for this);
///  - int `version`, `acceptedAt` a DateTime    → present (the repository has
///    already converted the wire `Timestamp` to a DateTime at the boundary,
///    like `createdAt` / `coupleEnded.at`);
///  - int `version`, `acceptedAt` PRESENT-but-not-a-DateTime → null (absent):
///    a corrupt timestamp voids the whole record, fail-closed.
Consent? _consentField(Map<String, dynamic> data) {
  final raw = data['consent'];
  if (raw is! Map) return null;
  final version = raw['version'];
  if (version is! int) return null;
  final acceptedAtRaw = raw['acceptedAt'];
  if (acceptedAtRaw == null) return Consent(version: version);
  if (acceptedAtRaw is! DateTime) return null;
  return Consent(version: version, acceptedAt: acceptedAtRaw);
}

T _enumField<T extends Enum>(
  Map<String, dynamic> data,
  String field,
  List<T> values,
) {
  final raw = data[field];
  if (raw is! String) {
    throw FormatException(
      'users doc field "$field": expected a string, got ${raw.runtimeType}',
    );
  }
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('users doc field "$field": unknown value "$raw"');
}

/// Reads an optional server-owned string field: absent (or explicit null) →
/// null; present but not a string → [FormatException], matching [_enumField]'s
/// loud style so a corrupt server value surfaces rather than silently voiding
/// a pairing.
String? _optionalString(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return null;
  if (raw is! String) {
    throw FormatException(
      'users doc field "$field": expected a string, got ${raw.runtimeType}',
    );
  }
  return raw;
}

/// Reads an optional server-owned timestamp field that the repository has
/// already converted to a [DateTime] at the Firestore boundary: absent (or
/// pending server stamp → explicit null) → null; anything else non-DateTime →
/// [FormatException], same loud style as [_optionalString].
DateTime? _optionalDateTime(Map<String, dynamic> data, String field) {
  final raw = data[field];
  if (raw == null) return null;
  if (raw is! DateTime) {
    throw FormatException(
      'users doc field "$field": expected a DateTime, got ${raw.runtimeType}',
    );
  }
  return raw;
}

/// Reads an optional NESTED timestamp — `data[outer][inner]` — that the
/// repository has already converted to a [DateTime] at the Firestore boundary
/// (ADR-019 D3's `coupleEnded.at`). Absent outer map → null; present but not a
/// map → [FormatException]; absent inner → null; present inner non-DateTime →
/// [FormatException]. The existing mapper does NOT convert nested maps by magic
/// (review finding APP-3), so this is spelled out explicitly and loudly.
DateTime? _nestedDateTime(
  Map<String, dynamic> data,
  String outer,
  String inner,
) {
  final rawOuter = data[outer];
  if (rawOuter == null) return null;
  if (rawOuter is! Map) {
    throw FormatException(
      'users doc field "$outer": expected a map, got ${rawOuter.runtimeType}',
    );
  }
  final rawInner = rawOuter[inner];
  if (rawInner == null) return null;
  if (rawInner is! DateTime) {
    throw FormatException(
      'users doc field "$outer.$inner": expected a DateTime, got '
      '${rawInner.runtimeType}',
    );
  }
  return rawInner;
}
