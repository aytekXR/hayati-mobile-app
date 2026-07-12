import 'package:flutter/material.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../settings_screen.dart';

/// The settings entry point — a state-independent host for the gear (ADR-018
/// Decision 7; review finding DVUX-7).
///
/// WHY A WRAPPER AND NOT "a gear in the home's SafeArea": both home screens
/// return a DIFFERENT Scaffold per state (loading / error / no-day-yet /
/// pack-update / question / completed), so "the SafeArea" names no single place.
/// Wrapping each home's ENTIRE build return once puts the gear in EVERY state —
/// including the error state, which is the one that matters most: a user whose
/// couple stream is erroring must still be able to reach the lock.
///
/// `AlignmentDirectional.topEnd` so RTL mirrors for free. The gear lives on the
/// two homes ONLY (solo reflections are as private as paired content, and the
/// lock must be reachable before pairing) — never on capture, preview, coach, or
/// the paywall.
class SettingsGearOverlay extends StatelessWidget {
  const SettingsGearOverlay({
    super.key,
    required this.child,
    required this.uid,
  });

  /// The home's per-state Scaffold.
  final Widget child;

  final String uid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settingsTitle,
              onPressed: () => showSettings(context, uid: uid),
            ),
          ),
        ),
      ],
    );
  }
}
