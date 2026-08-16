import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_settings_launcher.g.dart';

/// Opens the OS page where notification permission can actually be changed
/// (ADR-046 Decision 4).
///
/// **This seam exists because one state is unreachable from inside the app.**
/// iOS shows its notification dialog exactly once per install; after a decline,
/// `requestPermission()` returns the standing `denied` and shows nothing. No
/// build, no re-prompt and no reinstall-free path recovers it — the Settings app
/// is the only place, and until now nothing told the user that or took them
/// there.
///
/// Deliberately its own tiny seam on the app's ONE platform channel
/// (`hayati/device_privacy`, ADR-018 D6) rather than a new package: it is one
/// `UIApplication` call, and `permission_handler` / `app_settings` /
/// `url_launcher` would each add a transitive dependency surface and an
/// advisory-audit obligation (ADR-034) to wrap it. Two seams over one channel is
/// exactly the shape ADR-018 D6 already set with `AppIconSwitcher` and
/// `BiometricAuthenticator`.
abstract interface class NotificationSettingsLauncher {
  /// Opens the app's notification settings.
  ///
  /// **Throws [NotificationSettingsException] when the OS refuses** — it does
  /// not degrade to a silent no-op. That is the `AppIconSwitcher.setDiscreet`
  /// fail-direction (ADR-018 D7) and it is the load-bearing half here: a button
  /// that looks like it worked and did nothing is the exact defect this whole
  /// slice exists to remove.
  Future<void> open();
}

/// The only thing [NotificationSettingsLauncher.open] throws. Carries a short
/// static [code] and NOTHING else — never an OS-supplied message, which could
/// carry content into a Crashlytics breadcrumb (the no-content rule).
final class NotificationSettingsException implements Exception {
  const NotificationSettingsException(this.code);

  /// A short, static discriminator: the platform error code, or `'unsupported'`
  /// / `'channel-error'`.
  final String code;

  @override
  bool operator ==(Object other) =>
      other is NotificationSettingsException && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'NotificationSettingsException(code: $code)';
}

/// Provides the app's [NotificationSettingsLauncher].
///
/// Unimplemented at the base, on the `appIconSwitcherProvider` mold: the flavor
/// entrypoints override it with the channel-backed implementation and tests
/// override it per container — so `flutter test` never touches the channel.
@Riverpod(keepAlive: true)
NotificationSettingsLauncher notificationSettingsLauncher(Ref ref) =>
    throw StateError(
      'notificationSettingsLauncherProvider must be overridden at bootstrap '
      '(main_dev.dart / main_prod.dart) or per test container.',
    );
