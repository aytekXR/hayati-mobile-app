// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_source_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the device's [PushTokenSource].
///
/// **Nothing overrides this yet, and that is the design** (ADR-042 D2). The FCM
/// implementation needs `firebase_messaging`, which needs `aps-environment`,
/// which needs the Push Notifications capability on the App ID — measured ABSENT
/// on 2026-08-06. Until the flavor entrypoints override it, [PushTokenSync] is
/// wired, tested and inert: reading it throws, so `PushTokenSync` never resolves
/// it on a device that has no source, and the app behaves exactly as it does
/// today.

@ProviderFor(pushTokenSource)
const pushTokenSourceProvider = PushTokenSourceProvider._();

/// Provides the device's [PushTokenSource].
///
/// **Nothing overrides this yet, and that is the design** (ADR-042 D2). The FCM
/// implementation needs `firebase_messaging`, which needs `aps-environment`,
/// which needs the Push Notifications capability on the App ID — measured ABSENT
/// on 2026-08-06. Until the flavor entrypoints override it, [PushTokenSync] is
/// wired, tested and inert: reading it throws, so `PushTokenSync` never resolves
/// it on a device that has no source, and the app behaves exactly as it does
/// today.

final class PushTokenSourceProvider
    extends
        $FunctionalProvider<PushTokenSource, PushTokenSource, PushTokenSource>
    with $Provider<PushTokenSource> {
  /// Provides the device's [PushTokenSource].
  ///
  /// **Nothing overrides this yet, and that is the design** (ADR-042 D2). The FCM
  /// implementation needs `firebase_messaging`, which needs `aps-environment`,
  /// which needs the Push Notifications capability on the App ID — measured ABSENT
  /// on 2026-08-06. Until the flavor entrypoints override it, [PushTokenSync] is
  /// wired, tested and inert: reading it throws, so `PushTokenSync` never resolves
  /// it on a device that has no source, and the app behaves exactly as it does
  /// today.
  const PushTokenSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushTokenSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushTokenSourceHash();

  @$internal
  @override
  $ProviderElement<PushTokenSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushTokenSource create(Ref ref) {
    return pushTokenSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushTokenSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushTokenSource>(value),
    );
  }
}

String _$pushTokenSourceHash() => r'5c61ada66be7a048a471379682db1deb0d2a7940';
