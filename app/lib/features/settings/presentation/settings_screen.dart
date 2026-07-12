import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../data_rights/domain/data_rights_exception.dart';
import '../../data_rights/domain/data_rights_repository_provider.dart';
import '../../data_rights/presentation/delete_account_screen.dart';
import '../../data_rights/presentation/export_screen.dart';
import '../../privacy_lock/domain/biometric_authenticator.dart';
import '../../privacy_lock/domain/pin_lock_attempt_result.dart';
import '../../privacy_lock/presentation/state/privacy_lock_controller.dart';
import '../../profile/domain/relationship_profile.dart';
import '../../profile/presentation/state/profile_providers.dart';
import '../domain/app_icon_switcher.dart';
import 'pin_setup_screen.dart';
import 'widgets/pin_verify_dialog.dart';
import 'widgets/settings_error_line.dart';

/// Pushes the settings screen over the current route — the `showCoach` /
/// `showPaywall` exported-helper convention. Entered from the gear both homes
/// carry (`SettingsGearOverlay`).
Future<void> showSettings(BuildContext context, {required String uid}) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(uid: uid)));
}

/// The app's settings surface (ADR-018 Decision 7, extended by ADR-019 D6/D7):
/// app lock, the biometric accelerator, the discreet icon, the discreet-
/// notification override, the two data-rights rows (download / delete), sign out.
///
/// This screen is pushed INSIDE the Navigator (and sits below the gate like
/// everything else), so `showDialog` is legitimate here — unlike on the lock
/// screen, which has no Overlay ancestor at all (Decision 3). The PIN-verify and
/// DV-warning dialogs below are the whole reason that distinction is worth
/// stating twice.
///
/// M6.2 (ADR-019) extended this screen rather than inventing a surface — the KVKK
/// export/delete rows and the notification-privacy toggle land HERE, as Decision 7
/// reserved. Still deliberately NOT here in v1: a theme toggle (MVP OUT-list),
/// change-PIN (disable→enable covers it), hotline content (founder-gated).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Platform capabilities, probed once on mount. Rows that the platform cannot
  /// honour simply do not appear (Decision 7) — never a switch that lies.
  bool _supportsIcons = false;
  bool _biometricAvailable = false;
  bool _discreet = false;

  /// A platform (or callable) call is in flight — the row's control is inert
  /// until it lands.
  bool _iconBusy = false;
  bool _biometricBusy = false;
  bool _notificationPrivacyBusy = false;

  /// The one honest failure line per row, or null. Resolved against l10n at
  /// render time (the `SettingsErrorLine` idiom).
  String Function(AppLocalizations)? _iconError;
  String Function(AppLocalizations)? _biometricError;
  String Function(AppLocalizations)? _lockError;
  String Function(AppLocalizations)? _notificationPrivacyError;

  @override
  void initState() {
    super.initState();
    _probePlatform();
  }

  Future<void> _probePlatform() async {
    final icons = ref.read(appIconSwitcherProvider);
    final biometrics = ref.read(biometricAuthenticatorProvider);
    final supportsIcons = await icons.supportsAlternateIcons();
    final discreet = supportsIcons && await icons.isDiscreet();
    final biometricAvailable = await biometrics.isAvailable();
    if (!mounted) return;
    setState(() {
      _supportsIcons = supportsIcons;
      _discreet = discreet;
      _biometricAvailable = biometricAvailable;
    });
  }

  // ── Row 1: the app lock ──────────────────────────────────────────────────

  Future<void> _setUpPin() async {
    setState(() => _lockError = null);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<bool>(builder: (_) => const PinSetupScreen()));
    // The controller is the source of truth for the row's state; nothing to
    // reconcile here (a failed write left it disabled and said so on the setup
    // screen itself).
  }

  Future<void> _turnOffPin() async {
    setState(() => _lockError = null);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const PinVerifyDialog(),
    );
    if (pin == null || !mounted) return;
    final result = await ref
        .read(privacyLockControllerProvider.notifier)
        .disableLock(pin);
    if (!mounted) return;

    // The two refusals are NOT the same thing, and saying so was a lie (review
    // finding DVUX-4). A wrong PIN was compared and did not match. A cooldown
    // means the PIN was never even LOOKED at — asserting "that PIN didn't match"
    // there tells the owner they mistyped when they did not, on the one surface
    // where they are trying to prove they are the owner. (The disable path IS
    // attempt-bounded, exactly like the lock screen, or it would be an unbounded
    // PIN oracle — so a cooldown is genuinely reachable from here.)
    setState(() {
      _lockError = switch (result) {
        PinLockAttemptWrong() => (l10n) => l10n.settingsLockDisableFailed,
        PinLockAttemptCooldown() => (l10n) => l10n.settingsLockCooldown,
        PinLockAttemptAccepted() || PinLockAttemptAborted() => null,
      };
    });
  }

  // ── Row 2: the biometric accelerator ─────────────────────────────────────

  /// Turning the accelerator ON demands the **PIN**, not just the warning
  /// (post-implementation review finding LOCKBYPASS-2; ADR-018 D1 already said
  /// so — "re-enabling requires the PIN plus the warning again" — and the first
  /// implementation shipped only the warning).
  ///
  /// Why the PIN is load-bearing here, not ceremony: attaching a biometric is
  /// attaching a SECOND CREDENTIAL to the lock, which is at least as
  /// security-significant as removing it — and removing it already demands the
  /// PIN. Without this, a partner who catches the phone momentarily unlocked
  /// (inside the 60s grace, or simply handed it) can walk into Settings, flip
  /// this on, acknowledge a warning written for the owner, and have the record
  /// capture the enrollment state **with their own already-enrolled face inside
  /// it** — a permanent second key to the lock, obtained silently, without ever
  /// knowing the PIN. The enrollment-change revocation cannot save us there: the
  /// enrollment never changed *after* enable; the attacker was captured *in* it.
  /// That would turn a transient unlocked-phone window into persistent access
  /// and break D4's honest promise that access cannot be gained *silently*.
  ///
  /// Turning it OFF needs no PIN: it only ever REDUCES access (fail-safe).
  Future<void> _setBiometric(bool enabled) async {
    setState(() {
      _biometricError = null;
      _biometricBusy = true;
    });
    try {
      String? pin;
      if (enabled) {
        // The DV warning comes BEFORE any write (review finding DVUX-1): at
        // enable time the app cannot know WHOSE face or finger is enrolled on
        // this phone, and on a shared device that is the whole risk. Declining
        // leaves the toggle off and nothing written.
        final acknowledged = await showDialog<bool>(
          context: context,
          builder: (_) => const _BiometricWarningDialog(),
        );
        if (acknowledged != true || !mounted) return;

        pin = await showDialog<String>(
          context: context,
          builder: (_) => const PinVerifyDialog(),
        );
        if (pin == null || !mounted) return;
      }
      final ok = await ref
          .read(privacyLockControllerProvider.notifier)
          .setBiometricEnabled(enabled, pin: pin);
      if (!mounted) return;
      if (!ok) {
        setState(
          () => _biometricError = (l10n) => l10n.settingsBiometricFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  // ── Row 3: the discreet icon ─────────────────────────────────────────────

  Future<void> _setDiscreet(bool discreet) async {
    setState(() {
      _iconError = null;
      _iconBusy = true;
    });
    try {
      await ref.read(appIconSwitcherProvider).setDiscreet(discreet);
      if (!mounted) return;
      setState(() => _discreet = discreet);
    } on AppIconException {
      // REVERT (Decision 7's fail-direction row): the switch keeps its old
      // value because the OS refused the new one. We never render a state the
      // platform did not accept — a discreet icon the user believes is applied,
      // and is not, is the worst possible lie on this screen.
      if (!mounted) return;
      setState(() => _iconError = (l10n) => l10n.settingsDiscreetFailed);
    } finally {
      if (mounted) setState(() => _iconBusy = false);
    }
  }

  // ── Row 4: the discreet-notification override (ADR-019 D6) ───────────────

  /// Turning the override ON writes `notificationPrivacy: 'discreet'`; OFF
  /// deletes the explicit value. The switch's VALUE is the explicit server field
  /// (streamed via the profile watch), not the resolved posture: an AR-locale
  /// user is discreet by default even with the field absent (v1 cannot override
  /// that protective default — the copy says so), yet flipping it on still writes
  /// the explicit value so the posture survives a later content-language change.
  Future<void> _setNotificationPrivacy(bool discreet) async {
    setState(() {
      _notificationPrivacyError = null;
      _notificationPrivacyBusy = true;
    });
    try {
      await ref
          .read(dataRightsRepositoryProvider)
          .updateNotificationPrivacy(discreet: discreet);
      // The profile stream re-emits the server-written field; the switch follows
      // it. On failure the server did not change, so the switch stays truthful.
    } on DataRightsException {
      if (!mounted) return;
      setState(
        () =>
            _notificationPrivacyError = (l10n) =>
                l10n.settingsNotificationPrivacyFailed,
      );
    } finally {
      if (mounted) setState(() => _notificationPrivacyBusy = false);
    }
  }

  // ── The two data-rights rows (ADR-019 D5/D7) ─────────────────────────────

  Future<void> _openExport() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ExportScreen()));

  Future<void> _openDelete() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()));

  @override
  Widget build(BuildContext context) {
    // Auth-loss self-pop (the CoachScreen idiom): a remote sign-out would
    // otherwise strand the user on this pushed route over the auth shell. The
    // ADR-019 delete flow's phase model exists precisely so this never fires on a
    // phase-1 cascade failure (state stays AuthSignedIn) — only on the real
    // AuthSignedOut/AuthError teardown transitions.
    ref.listen(authControllerProvider, (previous, next) {
      if (next is! AuthSignedIn) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final l10n = AppLocalizations.of(context);
    final lockState = ref.watch(privacyLockControllerProvider);
    final lockOn = lockState is! PrivacyLockDisabled;
    final biometricOn = ref
        .read(privacyLockControllerProvider.notifier)
        .biometricEnabled;
    // The discreet-notification switch reflects the EXPLICIT server field; the
    // AR subtitle notes the default is already on for Arabic content. Loading or
    // an error settles to no explicit override (the honest, non-lying default).
    final profile = switch (ref.watch(profileStreamProvider(widget.uid))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final notificationDiscreet = profile?.notificationPrivacyDiscreet ?? false;
    final isArabicContent = profile?.contentLanguage == ContentLanguage.ar;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.x4),
          children: [
            ListTile(
              title: Text(l10n.settingsLockTitle),
              subtitle: Text(
                lockOn
                    ? l10n.settingsLockSubtitleOn
                    : l10n.settingsLockSubtitleOff,
              ),
              trailing: TextButton(
                onPressed: lockOn ? _turnOffPin : _setUpPin,
                child: Text(
                  lockOn ? l10n.settingsLockTurnOff : l10n.settingsLockSetUp,
                ),
              ),
            ),
            SettingsErrorLine(resolve: _lockError),
            if (lockOn && _biometricAvailable) ...[
              SwitchListTile(
                value: biometricOn,
                onChanged: _biometricBusy ? null : _setBiometric,
                title: Text(l10n.settingsBiometricTitle),
                subtitle: Text(l10n.settingsBiometricSubtitle),
              ),
              SettingsErrorLine(resolve: _biometricError),
            ],
            if (_supportsIcons) ...[
              SwitchListTile(
                value: _discreet,
                onChanged: _iconBusy ? null : _setDiscreet,
                title: Text(l10n.settingsDiscreetTitle),
                // The honest bound (review finding DVUX-2): setAlternateIconName
                // changes the icon IMAGE only. CFBundleDisplayName has no
                // runtime API, so the app's NAME still shows under the icon.
                subtitle: Text(l10n.settingsDiscreetSubtitle),
              ),
              SettingsErrorLine(resolve: _iconError),
            ],
            SwitchListTile(
              value: notificationDiscreet,
              onChanged: _notificationPrivacyBusy
                  ? null
                  : _setNotificationPrivacy,
              title: Text(l10n.settingsNotificationPrivacyTitle),
              subtitle: Text(
                isArabicContent
                    ? l10n.settingsNotificationPrivacySubtitleAr
                    : l10n.settingsNotificationPrivacySubtitle,
              ),
            ),
            SettingsErrorLine(resolve: _notificationPrivacyError),
            ListTile(
              title: Text(l10n.dataRightsExportRowTitle),
              subtitle: Text(l10n.dataRightsExportRowSubtitle),
              trailing: const Icon(Icons.download_outlined),
              onTap: _openExport,
            ),
            ListTile(
              title: Text(l10n.dataRightsDeleteRowTitle),
              subtitle: Text(l10n.dataRightsDeleteRowSubtitle),
              trailing: const Icon(Icons.delete_outline),
              onTap: _openDelete,
            ),
            ListTile(
              title: Text(l10n.settingsSignOut),
              subtitle: Text(l10n.settingsSignOutSubtitle),
              trailing: const Icon(Icons.logout),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The DV warning shown BEFORE the biometric toggle is ever written (ADR-018
/// Decision 1; blocking review finding DVUX-1). Honest, not scary: the app truly
/// cannot enumerate whose biometrics are enrolled on this phone, and on a shared
/// device that is precisely the residual the user must weigh.
class _BiometricWarningDialog extends StatelessWidget {
  const _BiometricWarningDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsBiometricWarningTitle),
      content: Text(l10n.settingsBiometricWarningBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.settingsCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settingsBiometricWarningConfirm),
        ),
      ],
    );
  }
}
