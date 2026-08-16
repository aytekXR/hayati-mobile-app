import 'package:flutter/services.dart';

import '../../../core/platform/device_privacy_channel.dart';
import '../domain/notification_settings_launcher.dart';

/// [NotificationSettingsLauncher] over the app's one platform channel
/// (ADR-046 Decision 4, on the `ChannelAppIconSwitcher` mold).
///
/// Its own file, constructed ONLY in the entrypoints: `flutter test` never
/// imports it, so the channel is never touched under test and this device-only
/// code stays out of the coverage denominator (the ADR-018 TEST-5 split).
///
/// Every failure direction is a THROW, never a `false`. Opening the Settings app
/// is a navigation the user asked for and watched fail or succeed; a silent
/// no-op here would reproduce, one level down, the exact defect ADR-046 exists
/// to remove.
class ChannelNotificationSettingsLauncher
    implements NotificationSettingsLauncher {
  const ChannelNotificationSettingsLauncher([
    this._channel = const DevicePrivacyChannel(),
  ]);

  final DevicePrivacyChannel _channel;

  @override
  Future<void> open() async {
    try {
      await _channel.openNotificationSettings();
    } on MissingPluginException {
      throw const NotificationSettingsException('unsupported');
    } on PlatformException catch (failure) {
      // The CODE only — never `failure.message`: an OS-supplied string could
      // carry content into a Crashlytics breadcrumb (the no-content rule).
      throw NotificationSettingsException(failure.code);
    } catch (_) {
      throw const NotificationSettingsException('channel-error');
    }
  }
}
