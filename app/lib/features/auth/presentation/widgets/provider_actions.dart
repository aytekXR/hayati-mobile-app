import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/spacing_tokens.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../phone_sign_in_screen.dart';
import '../state/auth_controller.dart';

/// The three sign-in affordances (Apple, Google, phone), extracted from
/// `SignInScreen` so BOTH the auth shell and the partner-preview screen (M2.3)
/// can offer the same choice. On the preview the invitee sees who invited them
/// FIRST, then commits to sign-in through exactly these actions — one widget so
/// the two entry points can never drift.
///
/// The error view offers the same choice rather than a single "try again" bound
/// to one provider: an [AuthError] can come from any provider (or from a failed
/// sign-out), so a hardcoded retry would silently start a *different* flow than
/// the one that just failed.
class ProviderActions extends ConsumerWidget {
  const ProviderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(authControllerProvider.notifier);
    // Apple first (iOS-first convention), then Google, then phone.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: () => unawaited(notifier.signInWithApple()),
          child: Text(l10n.continueWithApple),
        ),
        const SizedBox(height: SpacingTokens.x3),
        FilledButton(
          onPressed: () => unawaited(notifier.signInWithGoogle()),
          child: Text(l10n.continueWithGoogle),
        ),
        const SizedBox(height: SpacingTokens.x3),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PhoneSignInScreen()),
          ),
          child: Text(l10n.continueWithPhone),
        ),
      ],
    );
  }
}
