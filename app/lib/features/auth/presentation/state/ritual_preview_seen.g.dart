// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_preview_seen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The reactive CHANGE signal beside the durable flag — the coupleEndedSeen /
/// nameCaptureDone idiom: `SignInScreen` reads the flag synchronously off
/// [LocalFlagStore] and watches this notifier, so completing the preview
/// swaps in the auth shell without a restart. [markSeen] bumps a version
/// AFTER the durable write lands.

@ProviderFor(RitualPreviewSeen)
const ritualPreviewSeenProvider = RitualPreviewSeenProvider._();

/// The reactive CHANGE signal beside the durable flag — the coupleEndedSeen /
/// nameCaptureDone idiom: `SignInScreen` reads the flag synchronously off
/// [LocalFlagStore] and watches this notifier, so completing the preview
/// swaps in the auth shell without a restart. [markSeen] bumps a version
/// AFTER the durable write lands.
final class RitualPreviewSeenProvider
    extends $NotifierProvider<RitualPreviewSeen, int> {
  /// The reactive CHANGE signal beside the durable flag — the coupleEndedSeen /
  /// nameCaptureDone idiom: `SignInScreen` reads the flag synchronously off
  /// [LocalFlagStore] and watches this notifier, so completing the preview
  /// swaps in the auth shell without a restart. [markSeen] bumps a version
  /// AFTER the durable write lands.
  const RitualPreviewSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ritualPreviewSeenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ritualPreviewSeenHash();

  @$internal
  @override
  RitualPreviewSeen create() => RitualPreviewSeen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$ritualPreviewSeenHash() => r'338f027efd15a9e1f89c70c2cf2a6c4d78d4f8df';

/// The reactive CHANGE signal beside the durable flag — the coupleEndedSeen /
/// nameCaptureDone idiom: `SignInScreen` reads the flag synchronously off
/// [LocalFlagStore] and watches this notifier, so completing the preview
/// swaps in the auth shell without a restart. [markSeen] bumps a version
/// AFTER the durable write lands.

abstract class _$RitualPreviewSeen extends $Notifier<int> {
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
