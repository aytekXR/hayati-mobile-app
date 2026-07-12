import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../../privacy_lock/domain/biometric_authenticator.dart';
import '../../privacy_lock/domain/pin_hasher.dart';
import '../../privacy_lock/presentation/state/privacy_lock_controller.dart';
import '../../privacy_lock/presentation/widgets/pin_keypad.dart';
import '../domain/app_icon_switcher.dart';
import 'pin_setup_screen.dart';

/// Pushes the settings screen over the current route — the `showCoach` /
/// `showPaywall` exported-helper convention. Entered from the gear both homes
/// carry (`SettingsGearOverlay`).
Future<void> showSettings(BuildContext context, {required String uid}) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(uid: uid)));
}

/// The app's first settings surface (ADR-018 Decision 7): four rows — app lock,
/// the biometric accelerator, the discreet icon, sign out.
///
/// This screen is pushed INSIDE the Navigator (and sits below the gate like
/// everything else), so `showDialog` is legitimate here — unlike on the lock
/// screen, which has no Overlay ancestor at all (Decision 3). The PIN-verify and
/// DV-warning dialogs below are the whole reason that distinction is worth
/// stating twice.
///
/// M6.2 extends this screen (KVKK export/delete) rather than inventing a
/// surface. Deliberately NOT here in v1: a theme toggle (MVP OUT-list), the
/// notification-privacy override (Decision 6's loud M6.2 deferral), change-PIN
/// (disable→enable covers it), hotline content (founder-gated).
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

  /// A platform call is in flight — the row's control is inert until it lands.
  bool _iconBusy = false;
  bool _biometricBusy = false;

  /// The one honest failure line per row, or null. Resolved against l10n at
  /// render time (the `_PairedErrorView` idiom).
  String Function(AppLocalizations)? _iconError;
  String Function(AppLocalizations)? _biometricError;
  String Function(AppLocalizations)? _lockError;

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
      builder: (_) => const _PinVerifyDialog(),
    );
    if (pin == null || !mounted) return;
    final ok = await ref
        .read(privacyLockControllerProvider.notifier)
        .disableLock(pin);
    if (!mounted) return;
    if (!ok) {
      // Honest either way: a wrong PIN and a running cooldown both mean "the
      // lock is still on" — and the wrong attempt was persisted (Decision 4:
      // disable is bounded exactly like the lock screen, or it would be an
      // unbounded oracle).
      setState(() => _lockError = (l10n) => l10n.settingsLockDisableFailed);
    }
  }

  // ── Row 2: the biometric accelerator ─────────────────────────────────────

  Future<void> _setBiometric(bool enabled) async {
    setState(() {
      _biometricError = null;
      _biometricBusy = true;
    });
    try {
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
      }
      final ok = await ref
          .read(privacyLockControllerProvider.notifier)
          .setBiometricEnabled(enabled);
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

  @override
  Widget build(BuildContext context) {
    // Auth-loss self-pop (the CoachScreen idiom): a remote sign-out would
    // otherwise strand the user on this pushed route over the auth shell.
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
            _ErrorLine(resolve: _lockError),
            if (lockOn && _biometricAvailable) ...[
              SwitchListTile(
                value: biometricOn,
                onChanged: _biometricBusy ? null : _setBiometric,
                title: Text(l10n.settingsBiometricTitle),
                subtitle: Text(l10n.settingsBiometricSubtitle),
              ),
              _ErrorLine(resolve: _biometricError),
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
              _ErrorLine(resolve: _iconError),
            ],
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

/// One honest failure line under the row that produced it, or nothing.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.resolve});

  final String Function(AppLocalizations)? resolve;

  @override
  Widget build(BuildContext context) {
    final resolve = this.resolve;
    if (resolve == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: SpacingTokens.cardPadding,
        end: SpacingTokens.cardPadding,
        bottom: SpacingTokens.x3,
      ),
      child: Text(
        resolve(AppLocalizations.of(context)),
        style: theme.textTheme.bodySmall?.copyWith(color: ColorTokens.alert),
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

/// PIN verification before the lock is turned off (ADR-018 Decision 1). A real
/// dialog, legitimately: this route is inside the Navigator (see the class doc
/// on [SettingsScreen]). Pops the entered PIN, or null on cancel; the PIN never
/// leaves this widget except as the argument to `disableLock`.
class _PinVerifyDialog extends StatefulWidget {
  const _PinVerifyDialog();

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsLockVerifyTitle),
      contentPadding: const EdgeInsets.symmetric(
        vertical: SpacingTokens.x5,
        horizontal: SpacingTokens.x2,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinDots(filled: _pin.length),
          const SizedBox(height: SpacingTokens.x5),
          PinKeypad(
            onDigit: (digit) {
              if (_pin.length >= kPinLength) return;
              setState(() => _pin += digit);
              if (_pin.length == kPinLength) Navigator.of(context).pop(_pin);
            },
            onBackspace: () {
              if (_pin.isEmpty) return;
              setState(() => _pin = _pin.substring(0, _pin.length - 1));
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCancel),
        ),
      ],
    );
  }
}
