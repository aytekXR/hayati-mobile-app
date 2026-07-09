/// Relationship stage captured at onboarding (docs/prd.md F1).
enum RelationshipStatus { dating, engaged, married }

/// Language of the daily questions and coach content. Independent of the UI
/// locale — bootstrapped from it, then owned by the profile
/// (docs/architecture.md §3 `users/{uid}`).
enum ContentLanguage { tr, ar, en }

/// Tone register (docs/prd.md F1). Product-meaningful for Turkish today
/// (packs `tr_playful` / `tr_respectful`); Arabic and English currently ship
/// a single pack each, so the capture flow only surfaces the choice for
/// Turkish and stores the default otherwise (pack resolution is M3).
enum ContentRegister { playful, respectful }

/// The couple-member profile captured at onboarding. Pure Dart, keyed
/// externally by uid (`users/{uid}` — docs/architecture.md §3).
///
/// Doctrine on server-owned fields: the client still NEVER writes any of them
/// back — `profileToMap` emits none, and [copyWith] cannot set them. What
/// changes at M2.3 is that one such field, [coupleId], now crosses the domain
/// boundary READ-ONLY: the join flow stamps it server-side and the app reads it
/// to route a paired user past onboarding, but a profile edit must PRESERVE —
/// never clobber — it (see `FirestoreProfileRepository.saveProfile`'s merge).
/// createdAt and fcmTokens remain server-only and still do not surface here.
class RelationshipProfile {
  const RelationshipProfile({
    required this.status,
    required this.contentLanguage,
    required this.register,
    this.coupleId,
  });

  final RelationshipStatus status;
  final ContentLanguage contentLanguage;
  final ContentRegister register;

  /// The couple this member belongs to once paired (`couples/{coupleId}`,
  /// docs/architecture.md §3), or null while still solo. Server-owned: read
  /// back from `users/{uid}` but never written from the client — hence it is
  /// deliberately NOT a [copyWith] parameter (a client edit must not invent or
  /// erase a pairing) yet is carried THROUGH copyWith so an edit preserves it.
  final String? coupleId;

  RelationshipProfile copyWith({
    RelationshipStatus? status,
    ContentLanguage? contentLanguage,
    ContentRegister? register,
  }) => RelationshipProfile(
    status: status ?? this.status,
    contentLanguage: contentLanguage ?? this.contentLanguage,
    register: register ?? this.register,
    coupleId: coupleId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipProfile &&
          other.status == status &&
          other.contentLanguage == contentLanguage &&
          other.register == register &&
          other.coupleId == coupleId;

  @override
  int get hashCode => Object.hash(status, contentLanguage, register, coupleId);

  @override
  String toString() =>
      'RelationshipProfile(status: $status, contentLanguage: '
      '$contentLanguage, register: $register, coupleId: $coupleId)';
}
