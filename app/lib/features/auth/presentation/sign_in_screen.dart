import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../pairing/presentation/partner_preview_screen.dart';
import '../../pairing/presentation/state/pending_invite.dart';
import '../../profile/presentation/onboarding_gate.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_state.dart';
import 'state/auth_controller.dart';
import 'widgets/provider_actions.dart';

/// Minimal auth shell for M1.1: one widget per [AuthState]. Brand styling comes
/// from the theme (core/design_system/hayati_theme.dart) and the spacing tokens
/// below; per-widget overrides only where a surface needs emphasis. Copy comes
/// from the ARB bundles (tr/ar/en, M1.2 — docs/architecture.md §6). Layout is
/// logical-direction only (RTL-safe).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    // Signed in → onboarding owns the whole screen (its children bring
    // their own Scaffolds); everything else renders in the auth shell.
    if (authState case AuthSignedIn(:final user)) {
      return OnboardingGate(user: user);
    }
    // NOT signed in but a pairing code is pending (deep link, or an invitee who
    // opened `hayati://invite/<code>` cold): show WHO invited them before they
    // commit to sign-in — the activation moment (M2.3). The preview screen
    // brings its own Scaffold like OnboardingGate, so return it directly.
    //
    // EXCEPT after a failed sign-in: an AuthError must fall through to the error
    // view below (which re-offers the providers with error copy) rather than be
    // swallowed by the preview. The pending code is keepAlive, so a successful
    // retry resumes the preview / join flow.
    if (authState is! AuthError && ref.watch(pendingInviteProvider) != null) {
      return const PartnerPreviewScreen();
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
            ),
            child: switch (authState) {
              AuthSignedOut() => const _SignedOutView(),
              AuthError(:final failure) => _ErrorView(failure: failure),
              _ => const CircularProgressIndicator(),
            },
          ),
        ),
      ),
    );
  }
}

class _SignedOutView extends ConsumerWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hero wordmark on the display role (sand — pomegranate-on-night fails
        // the >=4.5 contrast rule, so the brand text stays sand).
        Text(config.appName, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: SpacingTokens.x8),
        const ProviderActions(),
      ],
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.failure});

  final AuthException failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = switch (failure) {
      AuthNetworkException() => l10n.errorNetworkRetry,
      AuthInvalidCodeException() => l10n.errorInvalidCode,
      AuthSessionExpiredException() => l10n.errorSessionExpired,
      AuthCancelledException() || AuthUnknownException() => l10n.errorGeneric,
    };
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.signInFailedTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: SpacingTokens.x2),
        // Error copy in the theme's alert colour (alert-on-night 4.94:1 OK).
        Text(
          detail,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: SpacingTokens.x6),
        const ProviderActions(),
      ],
    );
  }
}
