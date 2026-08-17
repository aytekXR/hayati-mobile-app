import 'package:flutter/services.dart';

/// The app's FIRST (and only) platform channel — ONE channel for the whole
/// device-privacy layer (ADR-018 Decision 6): one native registration site, one
/// seam discipline. It carries the five native methods this layer needs:
///
/// * `supportsAlternateIcons` → `bool`
/// * `getAlternateIconName` → `String?` (null = the primary icon)
/// * `setAlternateIconName` (`{'name': String?}`, null = back to primary) → void
/// * `biometricEnrollmentState` → `String?` (iOS `LAContext`'s biometric
///   enrollment bytes, base64; null when unavailable). The native side reads
///   `domainState.biometry.stateHash` on iOS 18+ and the deprecated
///   `evaluatedPolicyDomainState` below it (ADR-018 rev 5, issue #47) — two
///   representations of the same opaque token, which this side never parses.
/// * `openNotificationSettings` → void (ADR-046 Decision 4). One more method on
///   the SAME channel rather than a new package: `permission_handler`,
///   `app_settings` and `url_launcher` would each add a transitive dependency
///   surface and an ADR-034 advisory obligation to wrap a single
///   `UIApplication.openSettingsURLString` call. Two seams over one channel is
///   the shape D6 already set.
///
/// This file is DEVICE-ONLY by construction: it is reached solely through the
/// `AppIconSwitcher` / `BiometricAuthenticator` adapters, which the entrypoints
/// construct and the tests never import (the coverage-neutrality split, review
/// finding TEST-5). Nothing here catches: each adapter owns its own failure
/// mapping (bool/null for the biometric seam, a thrown `AppIconException` for the
/// icon seam — never claim a state the OS refused, D7).
class DevicePrivacyChannel {
  const DevicePrivacyChannel([
    this._channel = const MethodChannel(kDevicePrivacyChannelName),
  ]);

  final MethodChannel _channel;

  Future<bool> supportsAlternateIcons() async =>
      await _channel.invokeMethod<bool>('supportsAlternateIcons') ?? false;

  Future<String?> getAlternateIconName() =>
      _channel.invokeMethod<String>('getAlternateIconName');

  Future<void> setAlternateIconName(String? name) =>
      _channel.invokeMethod<void>('setAlternateIconName', <String, String?>{
        'name': name,
      });

  Future<String?> biometricEnrollmentState() =>
      _channel.invokeMethod<String>('biometricEnrollmentState');

  /// Opens the app's own page in the iOS Settings app (ADR-046 D4). The only
  /// place a `denied` notification permission can be changed — iOS never shows
  /// its dialog a second time.
  Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');
}

/// The single channel name. The Swift half registers exactly this (Decision 6).
const String kDevicePrivacyChannelName = 'hayati/device_privacy';
