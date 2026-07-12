import 'package:flutter/services.dart';

/// The app's FIRST (and only) platform channel — ONE channel for the whole
/// device-privacy layer (ADR-018 Decision 6): one native registration site, one
/// seam discipline. It carries the four native methods this layer needs:
///
/// * `supportsAlternateIcons` → `bool`
/// * `getAlternateIconName` → `String?` (null = the primary icon)
/// * `setAlternateIconName` (`{'name': String?}`, null = back to primary) → void
/// * `biometricEnrollmentState` → `String?` (iOS
///   `LAContext.evaluatedPolicyDomainState`, base64; null when unavailable)
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
}

/// The single channel name. The Swift half registers exactly this (Decision 6).
const String kDevicePrivacyChannelName = 'hayati/device_privacy';
