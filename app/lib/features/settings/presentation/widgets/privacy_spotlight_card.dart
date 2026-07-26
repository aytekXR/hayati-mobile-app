import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/color_tokens.dart';
import '../../../../core/design_system/elevation_tokens.dart';
import '../../../../core/design_system/radius_tokens.dart';
import '../../../../core/design_system/spacing_tokens.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/storage/local_flag_store.dart';
import '../pin_setup_screen.dart';

/// The device-local "privacy spotlight handled" flag key (redesign M-6),
/// keyed per uid so the one-time card never leaks across accounts on a
/// shared device (the coach-ack / nameCaptureDone precedent). Set when the
/// user takes EITHER action — the card is a one-time invitation, and
/// Settings remains the permanent home of these controls.
String privacySpotlightSeenKey(String uid) => 'privacySpotlightSeen.$uid';

/// The one-time privacy spotlight (redesign M-6, ui-ux §6.1): a dismissible
/// Night Raised card atop the first solo home — never a modal, never a
/// blocking pane (Principle 7) — surfacing the headline privacy features
/// (PIN lock, discreet icon) at the moment trust forms. PRD F6 is a headline
/// differentiator for the GCC persona, yet PIN setup is otherwise invisible
/// until someone finds Settings.
///
/// Tone: care, never paranoia. The secondary action is "Maybe later" — never
/// "Skip", no judgment. "Set up my PIN" pushes the shipped [PinSetupScreen]
/// untouched (the DV warning and the PIN gate on biometric enablement live
/// there and in Settings, exactly as before — postures only strengthen).
///
/// Either action marks the per-uid [LocalFlagStore] flag, so the card shows
/// on at most one home ever; until an action is taken it re-renders on later
/// launches (an unanswered invitation stays open, it never re-prompts after
/// an answer). Renders [SizedBox.shrink] once handled, so the parent can
/// mount it unconditionally.
class PrivacySpotlightCard extends ConsumerStatefulWidget {
  const PrivacySpotlightCard({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<PrivacySpotlightCard> createState() =>
      _PrivacySpotlightCardState();
}

class _PrivacySpotlightCardState extends ConsumerState<PrivacySpotlightCard> {
  /// Synchronous first-frame gate off the durable flag (the LocalFlagStore
  /// contract exists exactly for this read); local state carries the
  /// dismissal for the rest of this session.
  late bool _visible = !ref
      .read(localFlagStoreProvider)
      .isSet(privacySpotlightSeenKey(widget.uid));

  /// Durable write + local hide. Idempotent; fire-and-forget at the call
  /// sites so a slow disk write never delays the tap response.
  Future<void> _markHandled() async {
    setState(() => _visible = false);
    await ref
        .read(localFlagStoreProvider)
        .set(privacySpotlightSeenKey(widget.uid));
  }

  void _setUpPin() {
    // The card is spent either way (one-time by design; Settings remains the
    // permanent home of the controls), then the shipped setup flow runs
    // unmodified on a pushed route.
    unawaited(_markHandled());
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PinSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      // The gap to whatever sits beneath lives INSIDE the widget so the
      // parent's layout is byte-identical once the card is spent.
      margin: const EdgeInsets.only(bottom: SpacingTokens.x6),
      padding: const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: RadiusTokens.cardRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: ElevationTokens.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Clay — the secondary-glyph role (§9.4). Stand-in for the
              // lattice-lock brand glyph (assets pending).
              Icon(
                Icons.lock_outline,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: SpacingTokens.x2),
              Expanded(
                child: Text(
                  l10n.privacySpotlightTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.x3),
          // Caption register in Mist (theme bodySmall).
          Text(l10n.privacySpotlightBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: SpacingTokens.x2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: SpacingTokens.x2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  // Mist, quieter than the Rose primary — and never "Skip".
                  style: TextButton.styleFrom(
                    foregroundColor: ColorTokens.mist,
                  ),
                  onPressed: () => unawaited(_markHandled()),
                  child: Text(l10n.privacySpotlightLater),
                ),
                TextButton(
                  onPressed: _setUpPin,
                  child: Text(l10n.privacySpotlightCta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
