import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';
import 'state/auth_controller.dart';

/// Minimal auth shell for M1.1: one widget per [AuthState]. Deliberately
/// unstyled beyond theme defaults — brandkit application is a later M1
/// slice, and copy is literal English until the ARB l10n slice lands
/// (docs/architecture.md §6). Layout is logical-direction only (RTL-safe).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: switch (authState) {
              AuthSigningIn() => const CircularProgressIndicator(),
              AuthSignedOut() => const _SignedOutView(),
              AuthError(:final failure) => _ErrorView(failure: failure),
              AuthSignedIn(:final user) => _SignedInView(user: user),
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
          child: const Text('Continue with Google'),
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
    final detail = switch (failure) {
      AuthNetworkException() => 'Check your connection and try again.',
      AuthCancelledException() ||
      AuthUnknownException() => 'Something went wrong. Please try again.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sign-in failed', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => unawaited(
            ref.read(authControllerProvider.notifier).signInWithGoogle(),
          ),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Placeholder for the real post-auth destination (pairing, M2).
        Text(
          user.displayName ?? user.email ?? user.uid,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () =>
              unawaited(ref.read(authControllerProvider.notifier).signOut()),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
