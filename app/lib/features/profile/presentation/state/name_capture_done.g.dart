// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'name_capture_done.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The reactive CHANGE signal beside the durable flag — the exact
/// [CoupleEndedSeen] idiom: the gate reads the flag off [LocalFlagStore]
/// synchronously and watches this notifier so completing the capture
/// re-evaluates the gate without a restart. [markDone] bumps a version AFTER
/// the durable write lands.

@ProviderFor(NameCaptureDone)
const nameCaptureDoneProvider = NameCaptureDoneProvider._();

/// The reactive CHANGE signal beside the durable flag — the exact
/// [CoupleEndedSeen] idiom: the gate reads the flag off [LocalFlagStore]
/// synchronously and watches this notifier so completing the capture
/// re-evaluates the gate without a restart. [markDone] bumps a version AFTER
/// the durable write lands.
final class NameCaptureDoneProvider
    extends $NotifierProvider<NameCaptureDone, int> {
  /// The reactive CHANGE signal beside the durable flag — the exact
  /// [CoupleEndedSeen] idiom: the gate reads the flag off [LocalFlagStore]
  /// synchronously and watches this notifier so completing the capture
  /// re-evaluates the gate without a restart. [markDone] bumps a version AFTER
  /// the durable write lands.
  const NameCaptureDoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nameCaptureDoneProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nameCaptureDoneHash();

  @$internal
  @override
  NameCaptureDone create() => NameCaptureDone();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$nameCaptureDoneHash() => r'95dc35436eb80f45f1c37f9577865eccab33a527';

/// The reactive CHANGE signal beside the durable flag — the exact
/// [CoupleEndedSeen] idiom: the gate reads the flag off [LocalFlagStore]
/// synchronously and watches this notifier so completing the capture
/// re-evaluates the gate without a restart. [markDone] bumps a version AFTER
/// the durable write lands.

abstract class _$NameCaptureDone extends $Notifier<int> {
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
