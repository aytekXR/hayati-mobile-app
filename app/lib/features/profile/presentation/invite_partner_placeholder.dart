import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/presentation/state/auth_controller.dart';

/// Placeholder destination after profile capture — real pairing (invite
/// code/link, WhatsApp share, partner preview) is M2. Carries the sign-out
/// affordance so dogfood builds can switch accounts.
class InvitePartnerPlaceholder extends ConsumerWidget {
  const InvitePartnerPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.invitePartnerTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(l10n.invitePartnerBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
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
