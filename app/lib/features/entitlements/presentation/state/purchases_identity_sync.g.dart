// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases_identity_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the RevenueCat identity in lockstep with the auth state (M4.2, ADR-014
/// Decision 2). keepAlive + activated from the app root (app.dart) via
/// `ref.listen(..., (_, _) {})` — the always-mounted seam.
///
/// [build] reads the CURRENT auth state first and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session; a listen-only design would skip `logIn` on every warm start and the
/// purchase guard would then block every legitimate warm-start purchase.
///
/// The state value is the last-synced identity (uid, or null when signed out) —
/// incidental; the sync is the side effect. Dedupe tracks that identity
/// including signed-out: `uid → same uid` and `null → null` are no-ops, and
/// `logOut()` fires only on a real signed-in → signed-out transition (never as
/// an initial action — `Purchases.logOut()` throws when the RC user is already
/// anonymous). `AuthSigningIn`/`AuthError` are transient and drive no action.
/// The purchases repository is resolved lazily, only when a sync action fires,
/// so a signed-out lifecycle never touches `purchasesRepositoryProvider`.

@ProviderFor(PurchasesIdentitySync)
const purchasesIdentitySyncProvider = PurchasesIdentitySyncProvider._();

/// Keeps the RevenueCat identity in lockstep with the auth state (M4.2, ADR-014
/// Decision 2). keepAlive + activated from the app root (app.dart) via
/// `ref.listen(..., (_, _) {})` — the always-mounted seam.
///
/// [build] reads the CURRENT auth state first and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session; a listen-only design would skip `logIn` on every warm start and the
/// purchase guard would then block every legitimate warm-start purchase.
///
/// The state value is the last-synced identity (uid, or null when signed out) —
/// incidental; the sync is the side effect. Dedupe tracks that identity
/// including signed-out: `uid → same uid` and `null → null` are no-ops, and
/// `logOut()` fires only on a real signed-in → signed-out transition (never as
/// an initial action — `Purchases.logOut()` throws when the RC user is already
/// anonymous). `AuthSigningIn`/`AuthError` are transient and drive no action.
/// The purchases repository is resolved lazily, only when a sync action fires,
/// so a signed-out lifecycle never touches `purchasesRepositoryProvider`.
final class PurchasesIdentitySyncProvider
    extends $NotifierProvider<PurchasesIdentitySync, String?> {
  /// Keeps the RevenueCat identity in lockstep with the auth state (M4.2, ADR-014
  /// Decision 2). keepAlive + activated from the app root (app.dart) via
  /// `ref.listen(..., (_, _) {})` — the always-mounted seam.
  ///
  /// [build] reads the CURRENT auth state first and syncs it, THEN listens for
  /// transitions — because `ref.listen` never fires for the value already present
  /// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
  /// session; a listen-only design would skip `logIn` on every warm start and the
  /// purchase guard would then block every legitimate warm-start purchase.
  ///
  /// The state value is the last-synced identity (uid, or null when signed out) —
  /// incidental; the sync is the side effect. Dedupe tracks that identity
  /// including signed-out: `uid → same uid` and `null → null` are no-ops, and
  /// `logOut()` fires only on a real signed-in → signed-out transition (never as
  /// an initial action — `Purchases.logOut()` throws when the RC user is already
  /// anonymous). `AuthSigningIn`/`AuthError` are transient and drive no action.
  /// The purchases repository is resolved lazily, only when a sync action fires,
  /// so a signed-out lifecycle never touches `purchasesRepositoryProvider`.
  const PurchasesIdentitySyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchasesIdentitySyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchasesIdentitySyncHash();

  @$internal
  @override
  PurchasesIdentitySync create() => PurchasesIdentitySync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$purchasesIdentitySyncHash() =>
    r'2bc1bdf821468faba3a6fb6e6a84ed91a69d1607';

/// Keeps the RevenueCat identity in lockstep with the auth state (M4.2, ADR-014
/// Decision 2). keepAlive + activated from the app root (app.dart) via
/// `ref.listen(..., (_, _) {})` — the always-mounted seam.
///
/// [build] reads the CURRENT auth state first and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session; a listen-only design would skip `logIn` on every warm start and the
/// purchase guard would then block every legitimate warm-start purchase.
///
/// The state value is the last-synced identity (uid, or null when signed out) —
/// incidental; the sync is the side effect. Dedupe tracks that identity
/// including signed-out: `uid → same uid` and `null → null` are no-ops, and
/// `logOut()` fires only on a real signed-in → signed-out transition (never as
/// an initial action — `Purchases.logOut()` throws when the RC user is already
/// anonymous). `AuthSigningIn`/`AuthError` are transient and drive no action.
/// The purchases repository is resolved lazily, only when a sync action fires,
/// so a signed-out lifecycle never touches `purchasesRepositoryProvider`.

abstract class _$PurchasesIdentitySync extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
