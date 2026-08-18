// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_funnel_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The three funnel events that are STATE TRANSITIONS rather than user actions
/// (`install`, `signup`, `paired`) — ADR-057 D4, on the `PushTokenSync` /
/// `PurchasesIdentitySync` mold: a keepAlive provider activated from the
/// always-mounted app root, reading the CURRENT state rather than only listening
/// for transitions (a listen-only design misses the value already present, which
/// on a warm start is every one of these).
///
/// **`paired` is emitted from the PROFILE, not from the join flow, and that is
/// the load-bearing choice here.** `JoinInviteController` is the obvious home
/// and it is wrong: only the **joiner** ever runs it. The **inviter** becomes
/// half of a couple without touching that controller at all, so a join-flow
/// emitter would report roughly half the pairings that happened — and Gate 2 is
/// *"pairing ≥40% of signups"*, so the metric the whole funnel exists to answer
/// would read about half its true value, with nothing anywhere reading red.
/// `users/{uid}.coupleId` is stamped server-side for **both** members, so
/// watching it catches both.
///
/// De-duplication is the emitter's (ADR-057 D4): this may re-run on every auth
/// or profile tick and the once-keys make that harmless, so nothing here needs
/// its own latch.
///
/// **Guarded, and not out of habit.** `authControllerProvider` resolves
/// `authRepositoryProvider`, which throws when unoverridden — every widget test
/// that does not wire auth. This provider is activated from `HayatiApp.build`,
/// so an unguarded throw here would take those tests down at build time. The
/// funnel degrades; the app does not (ADR-039 D1).

@ProviderFor(analyticsFunnelSync)
const analyticsFunnelSyncProvider = AnalyticsFunnelSyncProvider._();

/// The three funnel events that are STATE TRANSITIONS rather than user actions
/// (`install`, `signup`, `paired`) — ADR-057 D4, on the `PushTokenSync` /
/// `PurchasesIdentitySync` mold: a keepAlive provider activated from the
/// always-mounted app root, reading the CURRENT state rather than only listening
/// for transitions (a listen-only design misses the value already present, which
/// on a warm start is every one of these).
///
/// **`paired` is emitted from the PROFILE, not from the join flow, and that is
/// the load-bearing choice here.** `JoinInviteController` is the obvious home
/// and it is wrong: only the **joiner** ever runs it. The **inviter** becomes
/// half of a couple without touching that controller at all, so a join-flow
/// emitter would report roughly half the pairings that happened — and Gate 2 is
/// *"pairing ≥40% of signups"*, so the metric the whole funnel exists to answer
/// would read about half its true value, with nothing anywhere reading red.
/// `users/{uid}.coupleId` is stamped server-side for **both** members, so
/// watching it catches both.
///
/// De-duplication is the emitter's (ADR-057 D4): this may re-run on every auth
/// or profile tick and the once-keys make that harmless, so nothing here needs
/// its own latch.
///
/// **Guarded, and not out of habit.** `authControllerProvider` resolves
/// `authRepositoryProvider`, which throws when unoverridden — every widget test
/// that does not wire auth. This provider is activated from `HayatiApp.build`,
/// so an unguarded throw here would take those tests down at build time. The
/// funnel degrades; the app does not (ADR-039 D1).

final class AnalyticsFunnelSyncProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// The three funnel events that are STATE TRANSITIONS rather than user actions
  /// (`install`, `signup`, `paired`) — ADR-057 D4, on the `PushTokenSync` /
  /// `PurchasesIdentitySync` mold: a keepAlive provider activated from the
  /// always-mounted app root, reading the CURRENT state rather than only listening
  /// for transitions (a listen-only design misses the value already present, which
  /// on a warm start is every one of these).
  ///
  /// **`paired` is emitted from the PROFILE, not from the join flow, and that is
  /// the load-bearing choice here.** `JoinInviteController` is the obvious home
  /// and it is wrong: only the **joiner** ever runs it. The **inviter** becomes
  /// half of a couple without touching that controller at all, so a join-flow
  /// emitter would report roughly half the pairings that happened — and Gate 2 is
  /// *"pairing ≥40% of signups"*, so the metric the whole funnel exists to answer
  /// would read about half its true value, with nothing anywhere reading red.
  /// `users/{uid}.coupleId` is stamped server-side for **both** members, so
  /// watching it catches both.
  ///
  /// De-duplication is the emitter's (ADR-057 D4): this may re-run on every auth
  /// or profile tick and the once-keys make that harmless, so nothing here needs
  /// its own latch.
  ///
  /// **Guarded, and not out of habit.** `authControllerProvider` resolves
  /// `authRepositoryProvider`, which throws when unoverridden — every widget test
  /// that does not wire auth. This provider is activated from `HayatiApp.build`,
  /// so an unguarded throw here would take those tests down at build time. The
  /// funnel degrades; the app does not (ADR-039 D1).
  const AnalyticsFunnelSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsFunnelSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsFunnelSyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return analyticsFunnelSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$analyticsFunnelSyncHash() =>
    r'04d75ef14061cc9e452e587c32b921878be1bb24';
