// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the device's FCM registration token in lockstep with the auth state
/// (ADR-042 Decision 1/D6), on the `PurchasesIdentitySync` mold.
///
/// [build] reads the CURRENT auth state and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session. A listen-only design would skip registration on every warm start,
/// which is the shape of the bug `PurchasesIdentitySync` was written to avoid.
///
/// **The sign-out removal is a privacy control, not a cleanup task.** A token
/// that outlives a sign-out delivers the NEXT user's pushes to the PREVIOUS
/// user's phone. It is best-effort all the same: `registerPushToken` evicts the
/// token from every other user document server-side (ADR-042 D1), so the property
/// survives a sign-out whose cleanup never ran — a killed app, a revoked session,
/// a phone in a drawer. Registration is authoritative; this is the prompt path,
/// not the load-bearing one.
///
/// **It removes the token it registered, not one re-read at sign-out.** FCM can
/// rotate a token between sign-in and sign-out, and removing the new one would
/// leave the old one on the departing user's document — the exact leak the call
/// exists to prevent.
///
/// Nothing here can take down the tree or block a frame: ADR-039 D1 makes the
/// boot fail-open and D2 bounds every wait on the launch→paired path. A device
/// with no token yet is the normal pre-permission state, not an error, and a
/// failure to obtain or register one is a logged no-op exactly as App Check and
/// Crashlytics fail open where they stand.
///
/// This provider is wired and **inert until `pushTokenSourceProvider` is
/// overridden** (ADR-042 D2 step 4, blocked on the App ID capability measured
/// absent on 2026-08-06). Resolving the source is deferred to the moment a sync
/// actually fires, so a signed-out lifecycle never touches it at all.

@ProviderFor(PushTokenSync)
const pushTokenSyncProvider = PushTokenSyncProvider._();

/// Keeps the device's FCM registration token in lockstep with the auth state
/// (ADR-042 Decision 1/D6), on the `PurchasesIdentitySync` mold.
///
/// [build] reads the CURRENT auth state and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session. A listen-only design would skip registration on every warm start,
/// which is the shape of the bug `PurchasesIdentitySync` was written to avoid.
///
/// **The sign-out removal is a privacy control, not a cleanup task.** A token
/// that outlives a sign-out delivers the NEXT user's pushes to the PREVIOUS
/// user's phone. It is best-effort all the same: `registerPushToken` evicts the
/// token from every other user document server-side (ADR-042 D1), so the property
/// survives a sign-out whose cleanup never ran — a killed app, a revoked session,
/// a phone in a drawer. Registration is authoritative; this is the prompt path,
/// not the load-bearing one.
///
/// **It removes the token it registered, not one re-read at sign-out.** FCM can
/// rotate a token between sign-in and sign-out, and removing the new one would
/// leave the old one on the departing user's document — the exact leak the call
/// exists to prevent.
///
/// Nothing here can take down the tree or block a frame: ADR-039 D1 makes the
/// boot fail-open and D2 bounds every wait on the launch→paired path. A device
/// with no token yet is the normal pre-permission state, not an error, and a
/// failure to obtain or register one is a logged no-op exactly as App Check and
/// Crashlytics fail open where they stand.
///
/// This provider is wired and **inert until `pushTokenSourceProvider` is
/// overridden** (ADR-042 D2 step 4, blocked on the App ID capability measured
/// absent on 2026-08-06). Resolving the source is deferred to the moment a sync
/// actually fires, so a signed-out lifecycle never touches it at all.
final class PushTokenSyncProvider
    extends $NotifierProvider<PushTokenSync, String?> {
  /// Keeps the device's FCM registration token in lockstep with the auth state
  /// (ADR-042 Decision 1/D6), on the `PurchasesIdentitySync` mold.
  ///
  /// [build] reads the CURRENT auth state and syncs it, THEN listens for
  /// transitions — because `ref.listen` never fires for the value already present
  /// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
  /// session. A listen-only design would skip registration on every warm start,
  /// which is the shape of the bug `PurchasesIdentitySync` was written to avoid.
  ///
  /// **The sign-out removal is a privacy control, not a cleanup task.** A token
  /// that outlives a sign-out delivers the NEXT user's pushes to the PREVIOUS
  /// user's phone. It is best-effort all the same: `registerPushToken` evicts the
  /// token from every other user document server-side (ADR-042 D1), so the property
  /// survives a sign-out whose cleanup never ran — a killed app, a revoked session,
  /// a phone in a drawer. Registration is authoritative; this is the prompt path,
  /// not the load-bearing one.
  ///
  /// **It removes the token it registered, not one re-read at sign-out.** FCM can
  /// rotate a token between sign-in and sign-out, and removing the new one would
  /// leave the old one on the departing user's document — the exact leak the call
  /// exists to prevent.
  ///
  /// Nothing here can take down the tree or block a frame: ADR-039 D1 makes the
  /// boot fail-open and D2 bounds every wait on the launch→paired path. A device
  /// with no token yet is the normal pre-permission state, not an error, and a
  /// failure to obtain or register one is a logged no-op exactly as App Check and
  /// Crashlytics fail open where they stand.
  ///
  /// This provider is wired and **inert until `pushTokenSourceProvider` is
  /// overridden** (ADR-042 D2 step 4, blocked on the App ID capability measured
  /// absent on 2026-08-06). Resolving the source is deferred to the moment a sync
  /// actually fires, so a signed-out lifecycle never touches it at all.
  const PushTokenSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushTokenSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushTokenSyncHash();

  @$internal
  @override
  PushTokenSync create() => PushTokenSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pushTokenSyncHash() => r'6e271a4168469b3facbdf95c2ffde66e727f371c';

/// Keeps the device's FCM registration token in lockstep with the auth state
/// (ADR-042 Decision 1/D6), on the `PurchasesIdentitySync` mold.
///
/// [build] reads the CURRENT auth state and syncs it, THEN listens for
/// transitions — because `ref.listen` never fires for the value already present
/// and `AuthController.build()` seeds `AuthSignedIn` synchronously on a restored
/// session. A listen-only design would skip registration on every warm start,
/// which is the shape of the bug `PurchasesIdentitySync` was written to avoid.
///
/// **The sign-out removal is a privacy control, not a cleanup task.** A token
/// that outlives a sign-out delivers the NEXT user's pushes to the PREVIOUS
/// user's phone. It is best-effort all the same: `registerPushToken` evicts the
/// token from every other user document server-side (ADR-042 D1), so the property
/// survives a sign-out whose cleanup never ran — a killed app, a revoked session,
/// a phone in a drawer. Registration is authoritative; this is the prompt path,
/// not the load-bearing one.
///
/// **It removes the token it registered, not one re-read at sign-out.** FCM can
/// rotate a token between sign-in and sign-out, and removing the new one would
/// leave the old one on the departing user's document — the exact leak the call
/// exists to prevent.
///
/// Nothing here can take down the tree or block a frame: ADR-039 D1 makes the
/// boot fail-open and D2 bounds every wait on the launch→paired path. A device
/// with no token yet is the normal pre-permission state, not an error, and a
/// failure to obtain or register one is a logged no-op exactly as App Check and
/// Crashlytics fail open where they stand.
///
/// This provider is wired and **inert until `pushTokenSourceProvider` is
/// overridden** (ADR-042 D2 step 4, blocked on the App ID capability measured
/// absent on 2026-08-06). Resolving the source is deferred to the moment a sync
/// actually fires, so a signed-out lifecycle never touches it at all.

abstract class _$PushTokenSync extends $Notifier<String?> {
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
