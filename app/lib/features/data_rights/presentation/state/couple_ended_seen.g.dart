// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'couple_ended_seen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A tiny keepAlive notifier the onboarding gate watches so that acknowledging a
/// notice re-evaluates the gate reactively (review finding APP-2, pinned as
/// mechanism, not left to "the gate notices"). The gate reads the durable flag
/// off [LocalFlagStore] synchronously; this provider only carries the CHANGE
/// signal — [markSeen] bumps a version after the durable flag is written, and the
/// gate's `watch` re-runs against the now-set flag, dropping the notice.

@ProviderFor(CoupleEndedSeen)
const coupleEndedSeenProvider = CoupleEndedSeenProvider._();

/// A tiny keepAlive notifier the onboarding gate watches so that acknowledging a
/// notice re-evaluates the gate reactively (review finding APP-2, pinned as
/// mechanism, not left to "the gate notices"). The gate reads the durable flag
/// off [LocalFlagStore] synchronously; this provider only carries the CHANGE
/// signal — [markSeen] bumps a version after the durable flag is written, and the
/// gate's `watch` re-runs against the now-set flag, dropping the notice.
final class CoupleEndedSeenProvider
    extends $NotifierProvider<CoupleEndedSeen, int> {
  /// A tiny keepAlive notifier the onboarding gate watches so that acknowledging a
  /// notice re-evaluates the gate reactively (review finding APP-2, pinned as
  /// mechanism, not left to "the gate notices"). The gate reads the durable flag
  /// off [LocalFlagStore] synchronously; this provider only carries the CHANGE
  /// signal — [markSeen] bumps a version after the durable flag is written, and the
  /// gate's `watch` re-runs against the now-set flag, dropping the notice.
  const CoupleEndedSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coupleEndedSeenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coupleEndedSeenHash();

  @$internal
  @override
  CoupleEndedSeen create() => CoupleEndedSeen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$coupleEndedSeenHash() => r'2d92c52d486ef306d2842b26ca4bbbf1fa464ee4';

/// A tiny keepAlive notifier the onboarding gate watches so that acknowledging a
/// notice re-evaluates the gate reactively (review finding APP-2, pinned as
/// mechanism, not left to "the gate notices"). The gate reads the durable flag
/// off [LocalFlagStore] synchronously; this provider only carries the CHANGE
/// signal — [markSeen] bumps a version after the durable flag is written, and the
/// gate's `watch` re-runs against the now-set flag, dropping the notice.

abstract class _$CoupleEndedSeen extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
