import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../domain/invite_deep_link.dart';
import '../domain/issued_invite.dart';
import 'partner_preview_screen.dart';
import 'state/invite_share_controller.dart';

/// The real pairing entry point after profile capture (M2.2, replacing the M1
/// placeholder): issues the caller's invite via `createInvite`, shows the code
/// + expiry, and offers TWO ways to hand it to a partner — the platform share
/// sheet, and a plain copy of the link for the conversation the sheet cannot
/// reach.
///
/// The message is code-first per the product-copy pairing rewrite: the code
/// leads, the ❤️ closes off the glanceable first line, and the link trails. The
/// code keeps the lead even now that the link is a real https URL (ADR-036/039)
/// — a code survives being retyped, read aloud, or pasted into a chat app that
/// mangles URLs, and it is the only half that works for a partner who has the
/// app but never taps the link. Composed here from l10n + [inviteLinkFor], so
/// the launcher seam stays a dumb "share this string" adapter.
///
/// Brand styling comes from the theme (core/design_system) plus the spacing
/// tokens; logical-direction only (RTL-safe). Carries the sign-out affordance so
/// a stalled pairing never strands the user.
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
                const SizedBox(height: SpacingTokens.x2),
                // The share sheet is the primary path and stays primary. This
                // is the path it does not cover: the partner who is reached on
                // a channel the sheet has no target for, or who is already in
                // the conversation and only needs something to paste. Copying
                // the LINK rather than the code because the link contains the
                // code — a recipient can always retype the eight characters
                // out of the URL, but cannot reconstruct the URL from them.
                TextButton(
                  onPressed: () => _copyLink(context, l10n),
                  child: Text(l10n.inviteCopyLink),
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
    final link = inviteLinkFor(invite.code);
    final message = l10n.inviteShareMessage(invite.code, link);
    unawaited(ref.read(inviteShareControllerProvider.notifier).share(message));
  }

  void _copyLink(BuildContext context, AppLocalizations l10n) {
    // Read the messenger BEFORE the await: this widget can be swapped out by
    // the gate mid-copy (a partner joining lands `coupleId` and re-routes), and
    // `ScaffoldMessenger.of` on a deactivated context throws.
    final messenger = ScaffoldMessenger.of(context);
    // Clipboard.setData goes to a platform channel and can reject. Two rules,
    // both deliberate:
    //
    //  * the confirmation is shown only AFTER the write lands — never claim a
    //    copy that did not happen, or the user pastes an empty message;
    //  * the failure is swallowed with an explicit error arm rather than left
    //    unhandled. `installErrorHooks` routes an escaped async error to
    //    `recordError(..., fatal: true)`, and a clipboard hiccup is not a fatal
    //    crash — reporting it as one would poison the crash-free rate with an
    //    event nobody can act on.
    unawaited(
      Clipboard.setData(ClipboardData(text: inviteLinkFor(invite.code))).then(
        (_) => messenger.showSnackBar(
          SnackBar(content: Text(l10n.inviteCopiedConfirmation)),
        ),
        onError: (Object failure) =>
            debugPrint('invite link copy failed: $failure'),
      ),
    );
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
