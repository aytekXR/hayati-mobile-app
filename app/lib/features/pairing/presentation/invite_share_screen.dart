import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../domain/issued_invite.dart';
import 'partner_preview_screen.dart';
import 'state/invite_share_controller.dart';

/// The real pairing entry point after profile capture (M2.2, replacing the M1
/// placeholder): issues the caller's invite via `createInvite`, shows the code
/// + expiry, and shares the localized WhatsApp message (warm one-liner + code
/// + `hayati://invite/<code>` deep link, composed here from l10n). Brand
/// styling comes from the theme (core/design_system) plus the spacing tokens;
/// logical-direction only (RTL-safe). Carries the sign-out affordance so a
/// stalled pairing never strands the user.
class InviteShareScreen extends ConsumerWidget {
  const InviteShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = ref.watch(inviteShareControllerProvider);
    // Precedence over the AsyncValue flags (not the subtype — Riverpod 3
    // carries previous error/value across states), mirroring OnboardingGate:
    // in-flight (first issue or retry) → spinner; settled error → retry view;
    // settled data → the code + share affordance.
    if (invite.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (invite.error != null) {
      return const _InviteErrorView();
    }
    return _InviteReadyView(invite: invite.value!);
  }
}

class _InviteReadyView extends ConsumerWidget {
  const _InviteReadyView({required this.invite});

  final IssuedInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
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
                  l10n.invitePartnerTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(l10n.inviteShareBody, textAlign: TextAlign.center),
                const SizedBox(height: SpacingTokens.x6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.x6,
                    vertical: SpacingTokens.cardPadding,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: RadiusTokens.cardRadius,
                  ),
                  child: Text(
                    invite.code,
                    style: theme.textTheme.displaySmall?.copyWith(
                      letterSpacing: SpacingTokens.x1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.inviteCodeExpiresAt(invite.expiresAt),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(
                  onPressed: () => _share(ref, l10n),
                  child: Text(l10n.inviteShareButton),
                ),
                const SizedBox(height: SpacingTokens.x4),
                // Modest cross-path for the invitee who received only a WhatsApp
                // code (no deep link): opens the partner-preview / manual-entry
                // screen so they can type it. Pushed (not a gate re-route) so a
                // dismiss pops straight back here.
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PartnerPreviewScreen(),
                    ),
                  ),
                  child: Text(l10n.joinHaveCodeAction),
                ),
                const SizedBox(height: SpacingTokens.x4),
                TextButton(
                  onPressed: () => unawaited(
                    ref.read(authControllerProvider.notifier).signOut(),
                  ),
                  child: Text(l10n.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _share(WidgetRef ref, AppLocalizations l10n) {
    // The share text is composed HERE (l10n + deep link) so the launcher seam
    // stays a dumb "share this string" adapter and the message is asserted in
    // widget tests without a method channel.
    final link = 'hayati://invite/${invite.code}';
    final message = l10n.inviteShareMessage(invite.code, link);
    unawaited(ref.read(inviteShareControllerProvider.notifier).share(message));
  }
}

class _InviteErrorView extends ConsumerWidget {
  const _InviteErrorView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error copy in the theme's alert colour (alert-on-night OK).
                Text(
                  l10n.inviteLoadFailedBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(
                  onPressed: () =>
                      ref.read(inviteShareControllerProvider.notifier).retry(),
                  child: Text(l10n.tryAgain),
                ),
                const SizedBox(height: SpacingTokens.x4),
                TextButton(
                  onPressed: () => unawaited(
                    ref.read(authControllerProvider.notifier).signOut(),
                  ),
                  child: Text(l10n.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
