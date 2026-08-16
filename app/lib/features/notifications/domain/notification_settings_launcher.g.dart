// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_settings_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [NotificationSettingsLauncher].
///
/// Unimplemented at the base, on the `appIconSwitcherProvider` mold: the flavor
/// entrypoints override it with the channel-backed implementation and tests
/// override it per container — so `flutter test` never touches the channel.

@ProviderFor(notificationSettingsLauncher)
const notificationSettingsLauncherProvider =
    NotificationSettingsLauncherProvider._();

/// Provides the app's [NotificationSettingsLauncher].
///
/// Unimplemented at the base, on the `appIconSwitcherProvider` mold: the flavor
/// entrypoints override it with the channel-backed implementation and tests
/// override it per container — so `flutter test` never touches the channel.

final class NotificationSettingsLauncherProvider
    extends
        $FunctionalProvider<
          NotificationSettingsLauncher,
          NotificationSettingsLauncher,
          NotificationSettingsLauncher
        >
    with $Provider<NotificationSettingsLauncher> {
  /// Provides the app's [NotificationSettingsLauncher].
  ///
  /// Unimplemented at the base, on the `appIconSwitcherProvider` mold: the flavor
  /// entrypoints override it with the channel-backed implementation and tests
  /// override it per container — so `flutter test` never touches the channel.
  const NotificationSettingsLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSettingsLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSettingsLauncherHash();

  @$internal
  @override
  $ProviderElement<NotificationSettingsLauncher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationSettingsLauncher create(Ref ref) {
    return notificationSettingsLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationSettingsLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationSettingsLauncher>(value),
    );
  }
}

String _$notificationSettingsLauncherHash() =>
    r'a06ed87646d5c6df85d6a4011e8c52f29289d6e5';
