import 'package:hayati_app/features/notifications/domain/notification_settings_launcher.dart';

/// Hand-written [NotificationSettingsLauncher] for the ADR-046 D3/D4 tests.
///
/// The failure knob is the point, not an extra: the launcher THROWS when the OS
/// refuses (ADR-018 D7's fail-direction, inherited deliberately), and a row that
/// swallowed that would put back exactly the silent no-op ADR-046 exists to
/// remove — a button that looks like it worked.
class FakeNotificationSettingsLauncher implements NotificationSettingsLauncher {
  FakeNotificationSettingsLauncher({this.failWith});

  /// Set to a [NotificationSettingsException] to prove the honest error line.
  NotificationSettingsException? failWith;

  int openCalls = 0;

  @override
  Future<void> open() async {
    openCalls++;
    if (failWith != null) throw failWith!;
  }
}
