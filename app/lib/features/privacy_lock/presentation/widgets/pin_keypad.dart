import 'package:flutter/material.dart';

import '../../../../core/design_system/color_tokens.dart';
import '../../../../core/design_system/spacing_tokens.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../domain/pin_hasher.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SENTINEL SCAN SET (ADR-025 D5.i, issue #61). This file is mounted by
// LockScreen, which sits ABOVE the app's only Navigator and has NO Navigator,
// NO Overlay and NO Scaffold ancestor — so the ADR-018 D3 constraint in
// `lock_screen.dart`'s header applies here in full: no `showDialog`, no
// `Tooltip` (and therefore no `tooltip:` argument and no `IconButton`, which
// builds one), no text-selection-enabled field, no `ScaffoldMessenger.of`.
// Each throws when its ancestor lookup fails, and on the recovery path that
// crash IS the lockout. `lock_screen_forbidden_api_sentinel_test.dart` reaches
// this file through LockScreen's import graph and enforces it.
//
// This is also why the keys below are hand-built from `InkWell` rather than
// `FilledButton`: see the S019 min-width note at [_PinKey].
// ═══════════════════════════════════════════════════════════════════════════

/// The 6-dot PIN echo (ADR-018 Decision 1 — dots only, never the digits).
///
/// Pinned LTR alongside the keypad: the dots fill in the same order the digits
/// are typed, and a mirrored echo against an unmirrored pad would read as a
/// bug in AR.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled});

  /// How many of the [kPinLength] dots are filled.
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // See [PinKeypad]: the PIN echo follows the pad, not the script.
      textDirection: TextDirection.ltr, // rtl-ok
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < kPinLength; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: SpacingTokens.x2),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? ColorTokens.sand : Colors.transparent,
                border: Border.all(color: ColorTokens.sand, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// The numeric PIN pad shared by the lock screen and PIN setup (ADR-018
/// Decision 1).
///
/// **Pinned `Directionality.ltr` on purpose (review finding DVUX-6).** Numeric
/// keypads are NOT mirrored in RTL on any platform — iOS's own passcode pad
/// renders 1-2-3 left-to-right in Arabic — so the repo's "logical direction,
/// RTL mirrors free" reflex must not reach this grid. ONLY the grid is pinned:
/// every line of copy around it stays locale-directional. The AR/RTL goldens
/// pin the 1-2-3 order.
///
/// Deliberately built from bare [InkWell]s rather than [FilledButton]s: the
/// app's FilledButton theme carries `minimumSize: Size.fromHeight(48)`, i.e. an
/// INFINITE minimum width, which a grid cell cannot satisfy.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  /// A digit key was pressed ('0'..'9'). Never fired while [enabled] is false.
  final ValueChanged<String> onDigit;

  /// The backspace key was pressed. Never fired while [enabled] is false.
  final VoidCallback onBackspace;

  /// False during a cooldown (ADR-018 Decision 4) — the pad greys out and
  /// swallows nothing: it simply stops responding.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // The whole point of this widget — see the class doc (DVUX-6).
      textDirection: TextDirection.ltr, // rtl-ok
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            _KeypadRow(
              children: [
                for (final digit in row)
                  _PinKey(
                    label: digit,
                    enabled: enabled,
                    onPressed: () => onDigit(digit),
                  ),
              ],
            ),
          _KeypadRow(
            children: [
              const _PinKeySpacer(),
              _PinKey(
                label: '0',
                enabled: enabled,
                onPressed: () => onDigit('0'),
              ),
              _PinKey(
                label: '',
                semanticLabel: AppLocalizations.of(context).lockBackspace,
                icon: Icons.backspace_outlined,
                enabled: enabled,
                onPressed: onBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: children,
  );
}

/// One 72×72 key with a >=44dp touch target (frontend-brandkit §8).
class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final String? semanticLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? ColorTokens.sand
        : ColorTokens.sand.withValues(alpha: 0.3);
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.x1),
      child: SizedBox(
        width: 68,
        height: 60,
        child: Material(
          color: ColorTokens.nightRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: color, semanticLabel: semanticLabel)
                  : Text(
                      label,
                      style: theme.textTheme.titleLarge?.copyWith(color: color),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeySpacer extends StatelessWidget {
  const _PinKeySpacer();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(SpacingTokens.x1),
    child: SizedBox(width: 68, height: 60),
  );
}
