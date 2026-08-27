// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_source_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the device's [PushTokenSource].
///
/// **BOTH flavor entrypoints override this** (`main_prod.dart`, `main_dev.dart`)
/// with `FcmPushTokenSource`, and have since ADR-042 D2 step 4 landed.
///
/// ⚠️ This doc comment said *"Nothing overrides this yet, and that is the
/// design"* until 2026-08-28, and it had been false for twenty days — one of
/// **five** comments across this feature still saying the device half could not
/// work (ADR-063). A stale *"this cannot work yet"* is the single most expensive
/// sentence in a repo, because it reads as a reason to stop looking.
///
/// So this comment states no measured fact about the device, the build or the
/// portal. **It names the instruments instead** — a comment that names a command
/// cannot go stale, because it makes no claim:
///
/// * has any device ever registered, and what does each phone say about itself?
///   `python3 tool/ci/push_delivery_probe.py --from-firebase-cli`
/// * is the App ID capability actually ticked?
///   `gh workflow run appid-capabilities.yml -f require=PUSH_NOTIFICATIONS`
///
/// The throw below stays: it is what keeps a container that forgot to override
/// this from silently behaving as though the device had no source. `PushTokenSync`
/// resolves it inside a guard and treats the throw as a logged no-op, so every
/// `flutter test` container that does not care about push is unaffected.

@ProviderFor(pushTokenSource)
const pushTokenSourceProvider = PushTokenSourceProvider._();

/// Provides the device's [PushTokenSource].
///
/// **BOTH flavor entrypoints override this** (`main_prod.dart`, `main_dev.dart`)
/// with `FcmPushTokenSource`, and have since ADR-042 D2 step 4 landed.
///
/// ⚠️ This doc comment said *"Nothing overrides this yet, and that is the
/// design"* until 2026-08-28, and it had been false for twenty days — one of
/// **five** comments across this feature still saying the device half could not
/// work (ADR-063). A stale *"this cannot work yet"* is the single most expensive
/// sentence in a repo, because it reads as a reason to stop looking.
///
/// So this comment states no measured fact about the device, the build or the
/// portal. **It names the instruments instead** — a comment that names a command
/// cannot go stale, because it makes no claim:
///
/// * has any device ever registered, and what does each phone say about itself?
///   `python3 tool/ci/push_delivery_probe.py --from-firebase-cli`
/// * is the App ID capability actually ticked?
///   `gh workflow run appid-capabilities.yml -f require=PUSH_NOTIFICATIONS`
///
/// The throw below stays: it is what keeps a container that forgot to override
/// this from silently behaving as though the device had no source. `PushTokenSync`
/// resolves it inside a guard and treats the throw as a logged no-op, so every
/// `flutter test` container that does not care about push is unaffected.

final class PushTokenSourceProvider
    extends
        $FunctionalProvider<PushTokenSource, PushTokenSource, PushTokenSource>
    with $Provider<PushTokenSource> {
  /// Provides the device's [PushTokenSource].
  ///
  /// **BOTH flavor entrypoints override this** (`main_prod.dart`, `main_dev.dart`)
  /// with `FcmPushTokenSource`, and have since ADR-042 D2 step 4 landed.
  ///
  /// ⚠️ This doc comment said *"Nothing overrides this yet, and that is the
  /// design"* until 2026-08-28, and it had been false for twenty days — one of
  /// **five** comments across this feature still saying the device half could not
  /// work (ADR-063). A stale *"this cannot work yet"* is the single most expensive
  /// sentence in a repo, because it reads as a reason to stop looking.
  ///
  /// So this comment states no measured fact about the device, the build or the
  /// portal. **It names the instruments instead** — a comment that names a command
  /// cannot go stale, because it makes no claim:
  ///
  /// * has any device ever registered, and what does each phone say about itself?
  ///   `python3 tool/ci/push_delivery_probe.py --from-firebase-cli`
  /// * is the App ID capability actually ticked?
  ///   `gh workflow run appid-capabilities.yml -f require=PUSH_NOTIFICATIONS`
  ///
  /// The throw below stays: it is what keeps a container that forgot to override
  /// this from silently behaving as though the device had no source. `PushTokenSync`
  /// resolves it inside a guard and treats the throw as a logged no-op, so every
  /// `flutter test` container that does not care about push is unaffected.
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
