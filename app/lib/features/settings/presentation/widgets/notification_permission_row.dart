import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../notifications/domain/notification_settings_launcher.dart';
import '../../../notifications/domain/push_registration.dart';
import '../../../notifications/presentation/state/push_token_sync.dart';
import 'settings_error_line.dart';

/// The row that says whether this phone can actually receive a notification —
/// and, when it cannot, what to do about it (ADR-046 Decision 3).
///
/// **It sits directly above the discreet-notification switch on purpose.** A
/// "hide notification content" toggle above a phone that receives no
/// notifications is exactly the confident-but-inert surface this whole slice
/// exists to remove: the app was measured on 2026-08-16 with four accounts, zero
/// registered devices, and zero HTTP requests ever reaching `registerPushToken`,
/// while every server-side layer was verified working.
///
/// Four device-side failures used to be indistinguishable from each other and
/// from success — never prompted, declined, granted-but-no-token, callable threw
/// — because each ended in a `debugPrint` that a TestFlight build routes
/// nowhere. This row is where they became four sentences and three buttons.
///
/// **Success is stated out loud**, not implied by the absence of a warning
/// (lesson 65: absence of evidence is not evidence of absence).
class NotificationPermissionRow extends ConsumerStatefulWidget {
  const NotificationPermissionRow({super.key});

  @override
  ConsumerState<NotificationPermissionRow> createState() =>
      _NotificationPermissionRowState();
}

class _NotificationPermissionRowState
    extends ConsumerState<NotificationPermissionRow> {
  bool _busy = false;
  String Function(AppLocalizations)? _error;

  @override
  void initState() {
    super.initState();
    // READ the standing answer — never `ensurePermission`, which would consume
    // iOS's one-per-install dialog just by opening Settings (ADR-046 D1). Safe
    // on every mount for exactly that reason.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(pushTokenSyncProvider.notifier).refresh());
    });
  }

  /// `notDetermined` only: run the ordinary ADR-042 D6 prompt path.
  Future<void> _turnOn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref
        .read(pushTokenSyncProvider.notifier)
        .promptForPermissionAndRegister();
    if (mounted) setState(() => _busy = false);
  }

  /// `awaitingDeviceToken` only: another bounded capture (ADR-046 D5). Bounded
  /// stays bounded — this starts a fresh ~7.5s run, it does not lift the cap.
  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(pushTokenSyncProvider.notifier).refresh();
    if (mounted) setState(() => _busy = false);
  }

  /// `denied` only: the door out. iOS will not show its dialog again, so this is
  /// the single remaining path and the copy says so.
  Future<void> _openSystemSettings() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(notificationSettingsLauncherProvider).open();
    } on NotificationSettingsException {
      // The OS refused. Say so and tell the user the manual route, rather than
      // leaving a button that looks like it worked — the ADR-018 D7
      // fail-direction, and the whole point of this row.
      if (mounted) {
        setState(() => _error = (l10n) => l10n.settingsNotificationsOpenFailed);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = (l10n) => l10n.settingsNotificationsOpenFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final registration = ref.watch(pushTokenSyncProvider);

    final (
      String subtitle,
      String? action,
      Future<void> Function()? onTap,
    ) = switch (registration.state) {
      PushRegistrationState.registered => (
        l10n.settingsNotificationsSubtitleOn,
        null,
        null,
      ),
      PushRegistrationState.denied => (
        l10n.settingsNotificationsSubtitleDenied,
        l10n.settingsNotificationsOpenSettings,
        _openSystemSettings,
      ),
      PushRegistrationState.awaitingDeviceToken => (
        l10n.settingsNotificationsSubtitleAwaiting,
        l10n.settingsNotificationsRetry,
        _retry,
      ),
      PushRegistrationState.notDetermined => (
        l10n.settingsNotificationsSubtitleOff,
        l10n.settingsNotificationsTurnOn,
        _turnOn,
      ),
      // Nothing measured yet — a signed-out container, or a build with no
      // source wired. Offer the prompt rather than a verdict: it is
      // idempotent, and claiming "off" for a state we have not read would be
      // the same unearned confidence this row exists to remove.
      PushRegistrationState.unknown => (
        l10n.settingsNotificationsSubtitleOff,
        l10n.settingsNotificationsTurnOn,
        _turnOn,
      ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(l10n.settingsNotificationsTitle),
          subtitle: Text(subtitle),
          trailing: action == null
              ? const Icon(Icons.notifications_active_outlined)
              : TextButton(
                  onPressed: _busy ? null : () => unawaited(onTap!()),
                  child: Text(action),
                ),
        ),
        SettingsErrorLine(resolve: _error),
      ],
    );
  }
}
