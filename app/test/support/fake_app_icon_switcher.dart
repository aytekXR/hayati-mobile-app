import 'package:hayati_app/features/settings/domain/app_icon_switcher.dart';

/// Hand-written [AppIconSwitcher] for the settings tests (ADR-018 Decision 6).
/// Scripted + a failure knob on [setDiscreet]: the toggle must REVERT with honest
/// copy when the OS refuses, never render a state the platform did not accept
/// (Decision 7's fail-direction row).
class FakeAppIconSwitcher implements AppIconSwitcher {
  FakeAppIconSwitcher({this.supported = true, this.discreet = false});

  /// Scripted [supportsAlternateIcons] / [isDiscreet] outcomes; [discreet] also
  /// records what a successful [setDiscreet] applied.
  bool supported;
  bool discreet;

  /// Ordered record of calls: `supportsAlternateIcons`, `isDiscreet`,
  /// `setDiscreet:<bool>`.
  final List<String> callLog = [];

  /// Set to a throwing closure (e.g. `(_) => throw const
  /// AppIconException('channel-error')`) to prove the revert path.
  Future<void> Function(bool discreet)? onSetDiscreet;

  @override
  Future<bool> supportsAlternateIcons() async {
    callLog.add('supportsAlternateIcons');
    return supported;
  }

  @override
  Future<bool> isDiscreet() async {
    callLog.add('isDiscreet');
    return discreet;
  }

  @override
  Future<void> setDiscreet(bool discreet) async {
    callLog.add('setDiscreet:$discreet');
    final handler = onSetDiscreet;
    if (handler != null) {
      await handler(discreet);
      return;
    }
    this.discreet = discreet;
  }
}
