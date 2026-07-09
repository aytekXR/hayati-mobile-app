import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../profile/presentation/onboarding_gate.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_state.dart';
import 'phone_sign_in_screen.dart';
import 'state/auth_controller.dart';

/// Minimal auth shell for M1.1: one widget per [AuthState]. Deliberately
/// unstyled beyond theme defaults — brandkit application is a later M1
/// slice. Copy comes from the ARB bundles (tr/ar/en, M1.2 —
/// docs/architecture.md §6). Layout is logical-direction only (RTL-safe).
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
        Text(config.appName, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 32),
        const _ProviderActions(),
      ],
    );
  }
}

/// The three sign-in affordances, shared by the signed-out and error views.
///
/// The error view offers the same choice rather than a single "try again"
/// bound to one provider: an [AuthError] can come from any provider (or from a
/// failed sign-out), so a hardcoded retry would silently start a *different*
/// flow than the one that just failed.
class _ProviderActions extends ConsumerWidget {
  const _ProviderActions();

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
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => unawaited(notifier.signInWithGoogle()),
          child: Text(l10n.continueWithGoogle),
        ),
        const SizedBox(height: 12),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.signInFailedTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        const _ProviderActions(),
      ],
    );
  }
}
