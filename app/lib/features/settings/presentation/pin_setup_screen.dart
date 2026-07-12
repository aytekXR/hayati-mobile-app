import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../privacy_lock/domain/pin_hasher.dart';
import '../../privacy_lock/presentation/state/privacy_lock_controller.dart';
import '../../privacy_lock/presentation/widgets/pin_keypad.dart';

/// PIN setup (ADR-018 Decision 1): enter → confirm → written to the Keychain
/// record. Pushed from the settings screen, so it is INSIDE the Navigator and
/// below the gate — unlike the lock screen, ordinary Navigator APIs are legal
/// here.
///
/// A mismatch restarts the flow with honest copy; a failed WRITE reports failure
/// and leaves the lock OFF (Decision 8: never claim protection that did not
/// persist). No PIN digit reaches any string, log, or exception.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  /// The first entry, held only until the confirm entry agrees with it.
  String? _first;

  String _pin = '';
  bool _saving = false;

  /// Set on mismatch (the flow restarts) or on a failed record write.
  String Function(AppLocalizations)? _error;

  void _onDigit(String digit) {
    if (_saving || _pin.length >= kPinLength) return;
    setState(() {
      _error = null;
      _pin += digit;
    });
    if (_pin.length == kPinLength) _advance();
  }

  void _onBackspace() {
    if (_saving || _pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _advance() {
    final first = _first;
    if (first == null) {
      setState(() {
        _first = _pin;
        _pin = '';
      });
      return;
    }
    if (first != _pin) {
      setState(() {
        _first = null;
        _pin = '';
        _error = (l10n) => l10n.settingsPinMismatch;
      });
      return;
    }
    _save(first);
  }

  Future<void> _save(String pin) async {
    setState(() => _saving = true);
    final ok = await ref
        .read(privacyLockControllerProvider.notifier)
        .enableLock(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _first = null;
      _pin = '';
      _error = (l10n) => l10n.settingsPinSaveFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPinSetupTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
              vertical: SpacingTokens.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _first == null
                      ? l10n.settingsPinEnterPrompt
                      : l10n.settingsPinConfirmPrompt,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: SpacingTokens.x6),
                PinDots(filled: _pin.length),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: SpacingTokens.x3),
                    child: Text(
                      error(l10n),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ColorTokens.alert,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: SpacingTokens.x6),
                const SizedBox(height: SpacingTokens.x4),
                PinKeypad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  enabled: !_saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
