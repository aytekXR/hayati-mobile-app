// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_icon_switcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [AppIconSwitcher].
///
/// Deliberately unimplemented at the base (the repository-seam discipline): the
/// flavor entrypoints override it BY VALUE with a `ChannelAppIconSwitcher`, and
/// tests with a `FakeAppIconSwitcher` — so `flutter test` never touches the
/// platform channel.

@ProviderFor(appIconSwitcher)
const appIconSwitcherProvider = AppIconSwitcherProvider._();

/// Provides the app's [AppIconSwitcher].
///
/// Deliberately unimplemented at the base (the repository-seam discipline): the
/// flavor entrypoints override it BY VALUE with a `ChannelAppIconSwitcher`, and
/// tests with a `FakeAppIconSwitcher` — so `flutter test` never touches the
/// platform channel.

final class AppIconSwitcherProvider
    extends
        $FunctionalProvider<AppIconSwitcher, AppIconSwitcher, AppIconSwitcher>
    with $Provider<AppIconSwitcher> {
  /// Provides the app's [AppIconSwitcher].
  ///
  /// Deliberately unimplemented at the base (the repository-seam discipline): the
  /// flavor entrypoints override it BY VALUE with a `ChannelAppIconSwitcher`, and
  /// tests with a `FakeAppIconSwitcher` — so `flutter test` never touches the
  /// platform channel.
  const AppIconSwitcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appIconSwitcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appIconSwitcherHash();

  @$internal
  @override
  $ProviderElement<AppIconSwitcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppIconSwitcher create(Ref ref) {
    return appIconSwitcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppIconSwitcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppIconSwitcher>(value),
    );
  }
}

String _$appIconSwitcherHash() => r'79d455136852745425de0d04579182d6ba428063';
