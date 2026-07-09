import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/presentation/state/auth_controller.dart';

/// Placeholder destination after profile capture — real pairing (invite
/// code/link, WhatsApp share, partner preview) is M2. Carries the sign-out
/// affordance so dogfood builds can switch accounts. Brand styling comes from
/// the theme (core/design_system/hayati_theme.dart) plus the spacing tokens.
class InvitePartnerPlaceholder extends ConsumerWidget {
  const InvitePartnerPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Text(
                  l10n.invitePartnerTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x2),
                Text(l10n.invitePartnerBody, textAlign: TextAlign.center),
                const SizedBox(height: SpacingTokens.x6),
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
