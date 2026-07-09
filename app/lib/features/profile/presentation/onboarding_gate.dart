import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/domain/auth_user.dart';
import '../domain/profile_exception.dart';
import 'invite_partner_placeholder.dart';
import 'profile_capture_screen.dart';
import 'state/profile_providers.dart';

/// Post-sign-in routing (docs/implementation-plan.md M1 accept criterion):
/// fresh signup → profile capture; existing profile → the M2 pairing
/// placeholder. Driven by the live `users/{uid}` stream so a profile saved
/// on the user's other device swaps this one without a restart.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileStreamProvider(user.uid));
    // Precedence over the AsyncValue flags (not the subtype — Riverpod 3
    // carries previous error/value across states): in-flight (first load or
    // explicit retry) → spinner; settled error → retry view; settled data →
    // route on profile presence.
    if (profile.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final error = profile.error;
    if (error != null) {
      return _GateErrorView(
        error: error,
        onRetry: () => ref.invalidate(profileStreamProvider(user.uid)),
      );
    }
    return profile.value == null
        ? ProfileCaptureScreen(uid: user.uid)
        : const InvitePartnerPlaceholder();
  }
}

class _GateErrorView extends StatelessWidget {
  const _GateErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detail = switch (error) {
      ProfileNetworkException() => l10n.errorNetworkRetry,
      _ => l10n.errorGeneric,
    };
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
                  detail,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: SpacingTokens.x6),
                FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
