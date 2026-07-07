// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the active flavor's [AppConfig].
///
/// Deliberately unimplemented at the base: each flavor entrypoint
/// (`main_dev.dart` / `main_prod.dart`) overrides it at the root
/// `ProviderScope`, and tests override it per container.

@ProviderFor(appConfig)
const appConfigProvider = AppConfigProvider._();

/// Provides the active flavor's [AppConfig].
///
/// Deliberately unimplemented at the base: each flavor entrypoint
/// (`main_dev.dart` / `main_prod.dart`) overrides it at the root
/// `ProviderScope`, and tests override it per container.

final class AppConfigProvider
    extends $FunctionalProvider<AppConfig, AppConfig, AppConfig>
    with $Provider<AppConfig> {
  /// Provides the active flavor's [AppConfig].
  ///
  /// Deliberately unimplemented at the base: each flavor entrypoint
  /// (`main_dev.dart` / `main_prod.dart`) overrides it at the root
  /// `ProviderScope`, and tests override it per container.
  const AppConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appConfigHash();

  @$internal
  @override
  $ProviderElement<AppConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppConfig create(Ref ref) {
    return appConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppConfig>(value),
    );
  }
}

String _$appConfigHash() => r'fdfb028b71b7e05b09cc7b6a7dd819df47133c7c';
