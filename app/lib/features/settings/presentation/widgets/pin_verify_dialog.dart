import 'package:flutter/material.dart';

import '../../../../core/design_system/spacing_tokens.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../privacy_lock/domain/pin_hasher.dart';
import '../../../privacy_lock/presentation/widgets/pin_keypad.dart';

/// PIN verification dialog (ADR-018 Decision 1; reused by ADR-019 D7's deletion
/// re-auth). A real dialog, legitimately: it is only ever shown from routes that
/// are pushed INSIDE the Navigator and below the gate (settings, the delete
/// screen) — unlike the lock screen, which has no Overlay ancestor at all
/// (Decision 3). Pops the entered PIN, or null on cancel; the PIN never leaves
/// this widget except as the caller's argument.
class PinVerifyDialog extends StatefulWidget {
  const PinVerifyDialog({super.key});

  @override
  State<PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<PinVerifyDialog> {
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
