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
/// externally by uid (`users/{uid}` — docs/architecture.md §3); server-owned
/// fields (createdAt, coupleId, fcmTokens) never cross the domain boundary.
class RelationshipProfile {
  const RelationshipProfile({
    required this.status,
    required this.contentLanguage,
    required this.register,
  });

  final RelationshipStatus status;
  final ContentLanguage contentLanguage;
  final ContentRegister register;

  RelationshipProfile copyWith({
    RelationshipStatus? status,
    ContentLanguage? contentLanguage,
    ContentRegister? register,
  }) => RelationshipProfile(
    status: status ?? this.status,
    contentLanguage: contentLanguage ?? this.contentLanguage,
    register: register ?? this.register,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipProfile &&
          other.status == status &&
          other.contentLanguage == contentLanguage &&
          other.register == register;

  @override
  int get hashCode => Object.hash(status, contentLanguage, register);

  @override
  String toString() =>
      'RelationshipProfile(status: $status, contentLanguage: '
      '$contentLanguage, register: $register)';
}
