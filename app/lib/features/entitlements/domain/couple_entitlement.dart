/// The couple's subscription entitlement read model (M4.1, ADR-013
/// Decision 5). Like [Couple], this is SERVER-OWNED read-only truth: the
/// `revenueCatWebhook` Function (admin SDK) is the sole writer of
/// `subscriptions/{coupleId}` and rules deny every client write. The app reads
/// only these summary fields — the per-uid `lanes` map is server bookkeeping
/// (ADR-013 Decision 4) and never crosses into the domain. Pure Dart; manual
/// value semantics, no equatable.
///
/// [entitled] is a PROJECTION ARTIFACT, never a grant on its own (ADR-013
/// Decision 5, binding on every consumer): a delayed EXPIRATION leaves the
/// mirror `entitled: true` with a past [expiresAt] for hours. The premium
/// decision therefore pairs the boolean with the [expiresAt] future-check —
/// see `isPremiumProvider`.
class CoupleEntitlement {
  const CoupleEntitlement({
    required this.entitled,
    this.productId,
    this.periodType,
    this.expiresAt,
    this.willRenew = false,
    this.store,
    this.environment,
  });

  /// The free/zero-state: no active subscription. This is the read model for a
  /// couple whose `subscriptions/{coupleId}` doc does not exist yet (every
  /// couple is free until the webhook writes otherwise — no backfill, ADR-013
  /// Decision 5) AND the value a present doc with `entitled: false` and no
  /// other fields maps to, so an absent doc and an explicit un-entitled doc are
  /// the same read model.
  static const free = CoupleEntitlement(entitled: false);

  /// Whether any lane is entitled (derived server-side, ADR-013 Decision 4).
  /// NEVER sufficient alone — see the class doc and [expiresAt].
  final bool entitled;

  /// The winning lane's product id (the store product), or null in the free
  /// state. Stored for forward-compatibility; the entitled/free decision is
  /// product-agnostic this session (ADR-013 Decision 2).
  final String? productId;

  /// The winning lane's RC period type (`NORMAL` / `TRIAL` / `INTRO` / ...), or
  /// null in the free state.
  final String? periodType;

  /// The winning lane's entitled-until instant (UTC), or null for a
  /// non-expiring entitlement (ADR-013: a null `expiresAtMs` is the
  /// non-expiring sentinel).
  final DateTime? expiresAt;

  /// The winning lane's auto-renew state (pinned per RC event type, ADR-013
  /// Decision 2). Defaults to false — the free/zero-state.
  final bool willRenew;

  /// The winning lane's store (`APP_STORE` / `PLAY_STORE` / ...), or null.
  final String? store;

  /// The RC environment (`SANDBOX` / `PRODUCTION`) stored verbatim, or null.
  /// No filtering: dev and prod are separate Firebase (and RC) projects
  /// (ADR-013 Decision 2).
  final String? environment;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleEntitlement &&
          other.entitled == entitled &&
          other.productId == productId &&
          other.periodType == periodType &&
          other.expiresAt == expiresAt &&
          other.willRenew == willRenew &&
          other.store == store &&
          other.environment == environment;

  @override
  int get hashCode => Object.hash(
    entitled,
    productId,
    periodType,
    expiresAt,
    willRenew,
    store,
    environment,
  );

  @override
  String toString() =>
      'CoupleEntitlement(entitled: $entitled, productId: $productId, '
      'periodType: $periodType, expiresAt: $expiresAt, willRenew: $willRenew, '
      'store: $store, environment: $environment)';
}
