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
    );

/// Client-owned fields only: server-owned fields (createdAt, coupleId,
/// fcmTokens — future milestones) are managed by the repository/Functions
/// and must never be emitted from here — [coupleId] is read back but NEVER
/// written, so a profile edit merges without touching the server's pairing.
/// Typed `Map<String, dynamic>` to match Firestore's API surface exactly
/// (keeps `set<T>` inference stable).
Map<String, dynamic> profileToMap(RelationshipProfile profile) => {
  'status': profile.status.name,
  'contentLanguage': profile.contentLanguage.name,
  'register': profile.register.name,
};

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
