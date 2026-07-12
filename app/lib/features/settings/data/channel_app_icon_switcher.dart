import 'package:flutter/services.dart';

import '../../../core/platform/device_privacy_channel.dart';
import '../domain/app_icon_switcher.dart';

/// [AppIconSwitcher] over the app's one platform channel (ADR-018 Decision 6).
///
/// Its own file, constructed ONLY in the entrypoints: `flutter test` never
/// imports it, so the channel is never touched under test and this device-only
/// code stays out of the coverage denominator (review finding TEST-5). Its
/// behaviour is device-verified on the operator checklist (item 4).
///
/// Failure directions differ per method ON PURPOSE (Decision 7): the two QUERIES
/// degrade to `false` (no support / not discreet → the row hides or reads off,
/// both safe), while [setDiscreet] THROWS so the UI can revert the switch — we
/// never render a state the OS refused.
class ChannelAppIconSwitcher implements AppIconSwitcher {
  const ChannelAppIconSwitcher([
    this._channel = const DevicePrivacyChannel(),
  ]);

  final DevicePrivacyChannel _channel;

  @override
  Future<bool> supportsAlternateIcons() async {
    try {
      return await _channel.supportsAlternateIcons();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isDiscreet() async {
    try {
      return await _channel.getAlternateIconName() == kDiscreetIconName;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setDiscreet(bool discreet) async {
    try {
      await _channel.setAlternateIconName(discreet ? kDiscreetIconName : null);
    } on MissingPluginException {
      throw const AppIconException('unsupported');
    } on PlatformException catch (failure) {
      // The CODE only — never `failure.message`: an OS-supplied string could
      // carry content into a Crashlytics breadcrumb (the no-content rule).
      throw AppIconException(failure.code);
    } catch (_) {
      throw const AppIconException('channel-error');
    }
  }
}
