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

/// The subject's recorded special-category consent (ADR-023 Decision 4), read
/// back from `users/{uid}.consent`. Server-owned: written ONLY by the
/// `recordConsent` callable (the server stamps [version] from its own
/// `CURRENT_LEGAL_VERSION`), never by the client — so, like [coupleId], it is
/// never emitted by `profileToMap` and never a `copyWith` parameter.
///
/// [acceptedAt] is nullable so the `Consented on {date}, version N` status line
/// can degrade gracefully (version only) rather than crash if the timestamp is
/// ever absent — the parse treats a MISSING `acceptedAt` as a present consent
/// with a null timestamp, but a PRESENT-but-wrong-type `acceptedAt` as junk (the
/// whole consent reads absent, fail-closed — the gate shows). The `ageAttested`
/// flag the server also stores is not surfaced here: no client UI decision reads
/// it (it lives in the provable server record and the subject's export).
class Consent {
  const Consent({required this.version, this.acceptedAt});

  /// The legal-bundle version the server stamped when this consent was granted.
  /// The gate compares it against `currentLegalVersion` via `hasCurrentConsent`.
  final int version;

  /// When the consent was granted (the server clock), or null if the stored
  /// field carried no valid timestamp. Rendered in the Settings legal hub.
  final DateTime? acceptedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Consent &&
          other.version == version &&
          other.acceptedAt == acceptedAt;

  @override
  int get hashCode => Object.hash(version, acceptedAt);

  @override
  String toString() => 'Consent(version: $version, acceptedAt: $acceptedAt)';
}

/// The couple-member profile captured at onboarding. Pure Dart, keyed
/// externally by uid (`users/{uid}` — docs/architecture.md §3).
///
/// Doctrine on server-owned fields: the client still NEVER writes any of them
/// back — `profileToMap` emits none, and [copyWith] cannot set them. What
/// changes at M2.3 is that one such field, [coupleId], now crosses the domain
/// boundary READ-ONLY: the join flow stamps it server-side and the app reads it
/// to route a paired user past onboarding, but a profile edit must PRESERVE —
/// never clobber — it (see `FirestoreProfileRepository.saveProfile`'s merge).
/// At M2.4 [createdAt] crosses the same way (READ-ONLY) to anchor the solo
/// day-N rotation; fcmTokens remain server-only and still do not surface here.
class RelationshipProfile {
  const RelationshipProfile({
    required this.status,
    required this.contentLanguage,
    required this.register,
    this.coupleId,
    this.createdAt,
    this.notificationPrivacyDiscreet = false,
    this.coupleEndedAt,
    this.consent,
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

  /// When the `users/{uid}` doc was first created — the rules-enforced,
  /// create-once server stamp (M1.2/M2.1) that anchors the solo day-N
  /// rotation (M2.4, `solo_day.dart`). Server-owned READ-ONLY like [coupleId]:
  /// never emitted by `profileToMap`, not a [copyWith] parameter, carried
  /// THROUGH copyWith. Null only inside the pending-serverTimestamp window
  /// (the local echo of the very first save) — treated as day 1.
  final DateTime? createdAt;

  /// Whether the per-user discreet-notification override is EXPLICITLY set
  /// (ADR-019 Decision 6). True only when `users/{uid}.notificationPrivacy ==
  /// 'discreet'` — an enum-safe defensive read where anything else (absent, junk)
  /// reads false; the AR-locale default is resolved server-side, not here.
  /// Server-owned: written by the `updateNotificationPrivacy` callable, never by
  /// the client — so, like [coupleId], it is NOT a [copyWith] parameter yet is
  /// carried THROUGH copyWith.
  final bool notificationPrivacyDiscreet;

  /// When this member's couple was ended by the partner's cascade deletion
  /// (ADR-019 Decision 3), mapped from the nested `users/{uid}.coupleEnded.at`
  /// Timestamp, or null while still paired / never-ended. Server-owned READ-ONLY
  /// (the rules freeze it): the app renders the honest terminal notice off it and
  /// never writes it. Carried THROUGH copyWith, not a parameter.
  final DateTime? coupleEndedAt;

  /// The subject's recorded special-category consent (ADR-023 D4), or null when
  /// no valid consent is stored yet — which is what the `OnboardingGate` consent
  /// branch reads through `hasCurrentConsent`. Server-owned READ-ONLY like
  /// [coupleId]: written only by the `recordConsent` callable, never emitted by
  /// `profileToMap`, not a [copyWith] parameter, carried THROUGH copyWith.
  final Consent? consent;

  RelationshipProfile copyWith({
    RelationshipStatus? status,
    ContentLanguage? contentLanguage,
    ContentRegister? register,
  }) => RelationshipProfile(
    status: status ?? this.status,
    contentLanguage: contentLanguage ?? this.contentLanguage,
    register: register ?? this.register,
    coupleId: coupleId,
    createdAt: createdAt,
    notificationPrivacyDiscreet: notificationPrivacyDiscreet,
    coupleEndedAt: coupleEndedAt,
    consent: consent,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipProfile &&
          other.status == status &&
          other.contentLanguage == contentLanguage &&
          other.register == register &&
          other.coupleId == coupleId &&
          other.createdAt == createdAt &&
          other.notificationPrivacyDiscreet == notificationPrivacyDiscreet &&
          other.coupleEndedAt == coupleEndedAt &&
          other.consent == consent;

  @override
  int get hashCode => Object.hash(
    status,
    contentLanguage,
    register,
    coupleId,
    createdAt,
    notificationPrivacyDiscreet,
    coupleEndedAt,
    consent,
  );

  @override
  String toString() =>
      'RelationshipProfile(status: $status, contentLanguage: '
      '$contentLanguage, register: $register, coupleId: $coupleId, '
      'createdAt: $createdAt, notificationPrivacyDiscreet: '
      '$notificationPrivacyDiscreet, coupleEndedAt: $coupleEndedAt, '
      'consent: $consent)';
}
