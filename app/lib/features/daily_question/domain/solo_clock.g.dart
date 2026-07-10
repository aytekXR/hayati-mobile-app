// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'solo_clock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's single wall-clock seam (M2.4). Unlike the repository seams this
/// has a safe pure default — the real clock — so the entrypoints don't
/// override it; tests do, to pin day-N and `soloDayKey` deterministically
/// (the "day 3 on day 3" acceptance proof must not depend on the test host's
/// clock). keepAlive: a clock has no per-screen lifetime.

@ProviderFor(soloClock)
const soloClockProvider = SoloClockProvider._();

/// The app's single wall-clock seam (M2.4). Unlike the repository seams this
/// has a safe pure default — the real clock — so the entrypoints don't
/// override it; tests do, to pin day-N and `soloDayKey` deterministically
/// (the "day 3 on day 3" acceptance proof must not depend on the test host's
/// clock). keepAlive: a clock has no per-screen lifetime.

final class SoloClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The app's single wall-clock seam (M2.4). Unlike the repository seams this
  /// has a safe pure default — the real clock — so the entrypoints don't
  /// override it; tests do, to pin day-N and `soloDayKey` deterministically
  /// (the "day 3 on day 3" acceptance proof must not depend on the test host's
  /// clock). keepAlive: a clock has no per-screen lifetime.
  const SoloClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soloClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soloClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return soloClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$soloClockHash() => r'c90923f8f4a7cc0b7a912089bfae7008e0e46f19';
