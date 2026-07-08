import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../profile/presentation/onboarding_gate.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_state.dart';
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
        FilledButton(
          onPressed: () => unawaited(
            ref.read(authControllerProvider.notifier).signInWithGoogle(),
          ),
          child: Text(AppLocalizations.of(context).continueWithGoogle),
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
        FilledButton(
          onPressed: () => unawaited(
            ref.read(authControllerProvider.notifier).signInWithGoogle(),
          ),
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}
