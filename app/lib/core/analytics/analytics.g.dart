// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where events go. **Defaults to silence** (ADR-057 D2c) — not to a throw.
///
/// `main_dev.dart` overrides it with the `DebugAnalyticsSink`. `main_prod.dart`
/// deliberately does not: prod ships the no-op until a vendor adapter and the
/// founder's Mixpanel token exist. Tests get the no-op for free, which is why
/// instrumenting a screen cannot redden an unrelated widget test.

@ProviderFor(analyticsSink)
const analyticsSinkProvider = AnalyticsSinkProvider._();

/// Where events go. **Defaults to silence** (ADR-057 D2c) — not to a throw.
///
/// `main_dev.dart` overrides it with the `DebugAnalyticsSink`. `main_prod.dart`
/// deliberately does not: prod ships the no-op until a vendor adapter and the
/// founder's Mixpanel token exist. Tests get the no-op for free, which is why
/// instrumenting a screen cannot redden an unrelated widget test.

final class AnalyticsSinkProvider
    extends $FunctionalProvider<AnalyticsSink, AnalyticsSink, AnalyticsSink>
    with $Provider<AnalyticsSink> {
  /// Where events go. **Defaults to silence** (ADR-057 D2c) — not to a throw.
  ///
  /// `main_dev.dart` overrides it with the `DebugAnalyticsSink`. `main_prod.dart`
  /// deliberately does not: prod ships the no-op until a vendor adapter and the
  /// founder's Mixpanel token exist. Tests get the no-op for free, which is why
  /// instrumenting a screen cannot redden an unrelated widget test.
  const AnalyticsSinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsSinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsSinkHash();

  @$internal
  @override
  $ProviderElement<AnalyticsSink> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsSink create(Ref ref) {
    return analyticsSink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsSink value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsSink>(value),
    );
  }
}

String _$analyticsSinkHash() => r'86f3bf961cac6d617bffa455aee701ad640a6892';

/// The §7 dimensions attached to every event (ADR-057 D3).
///
/// The BASE resolves the device locale and nothing else — correct for `install`
/// and `signup`, which fire before a profile exists. `app.dart` overrides it
/// with the profile-aware resolver, so a signed-in user's events carry the
/// register they actually chose. The override lives at the composition root
/// because nothing under `core/` may import `features/`.

@ProviderFor(analyticsDimensions)
const analyticsDimensionsProvider = AnalyticsDimensionsProvider._();

/// The §7 dimensions attached to every event (ADR-057 D3).
///
/// The BASE resolves the device locale and nothing else — correct for `install`
/// and `signup`, which fire before a profile exists. `app.dart` overrides it
/// with the profile-aware resolver, so a signed-in user's events carry the
/// register they actually chose. The override lives at the composition root
/// because nothing under `core/` may import `features/`.

final class AnalyticsDimensionsProvider
    extends
        $FunctionalProvider<
          AnalyticsDimensions,
          AnalyticsDimensions,
          AnalyticsDimensions
        >
    with $Provider<AnalyticsDimensions> {
  /// The §7 dimensions attached to every event (ADR-057 D3).
  ///
  /// The BASE resolves the device locale and nothing else — correct for `install`
  /// and `signup`, which fire before a profile exists. `app.dart` overrides it
  /// with the profile-aware resolver, so a signed-in user's events carry the
  /// register they actually chose. The override lives at the composition root
  /// because nothing under `core/` may import `features/`.
  const AnalyticsDimensionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsDimensionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsDimensionsHash();

  @$internal
  @override
  $ProviderElement<AnalyticsDimensions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnalyticsDimensions create(Ref ref) {
    return analyticsDimensions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsDimensions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsDimensions>(value),
    );
  }
}

String _$analyticsDimensionsHash() =>
    r'eff199da8914db59b9849edbda191d5775404ccf';

/// The app's funnel emitter (ADR-057).

@ProviderFor(analytics)
const analyticsProvider = AnalyticsProvider._();

/// The app's funnel emitter (ADR-057).

final class AnalyticsProvider
    extends $FunctionalProvider<Analytics, Analytics, Analytics>
    with $Provider<Analytics> {
  /// The app's funnel emitter (ADR-057).
  const AnalyticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsHash();

  @$internal
  @override
  $ProviderElement<Analytics> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Analytics create(Ref ref) {
    return analytics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Analytics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Analytics>(value),
    );
  }
}

String _$analyticsHash() => r'a977bc166ee62fb396bbf626686687c5f81773fb';
