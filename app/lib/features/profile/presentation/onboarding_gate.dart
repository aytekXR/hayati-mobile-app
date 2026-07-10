import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/domain/auth_user.dart';
import '../../daily_question/presentation/paired_home_screen.dart';
import '../../daily_question/presentation/solo_home_screen.dart';
import '../../pairing/presentation/partner_preview_screen.dart';
import '../../pairing/presentation/state/pending_invite.dart';
import '../domain/profile_exception.dart';
import 'profile_capture_screen.dart';
import 'state/profile_providers.dart';

/// Post-sign-in routing (docs/implementation-plan.md M1 criterion, extended at
/// M2.3/M2.4). Driven by the live `users/{uid}` stream plus the pending
/// deep-link invite so a profile saved — or a pairing completed — on the
/// user's other device swaps this one without a restart. Settled-data
/// precedence, in order:
///
///  1. profile == null            → capture (onboarding isn't done);
///  2. profile.coupleId != null   → the paired home (M3 slot) — the terminal
///     state wins over everything, so a just-joined user re-routes here the
///     moment `joinInvite` stamps the couple, whichever screen they came from;
///  3. pendingInvite != null      → the partner preview / join screen — an
///     onboarded-but-solo user who arrived on a `hayati://invite/<code>` link
///     sees who invited them and can accept;
///  4. otherwise                  → the solo home (M2.4): the day-N solo
///     reflection question with the persistent invite nudge — the share flow
///     stays one tap away behind the nudge.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileStreamProvider(user.uid));
    // Precedence over the AsyncValue flags (not the subtype — Riverpod 3
    // carries previous error/value across states): in-flight (first load or
    // explicit retry) → spinner; settled error → retry view; settled data →
    // route below.
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
    final value = profile.value;
    if (value == null) {
      return ProfileCaptureScreen(uid: user.uid);
    }
    // coupleId (paired) beats a still-pending invite: once paired, the invite
    // is spent and the pending code is stale.
    final coupleId = value.coupleId;
    if (coupleId != null) {
      return PairedHomeScreen(uid: user.uid, coupleId: coupleId);
    }
    if (ref.watch(pendingInviteProvider) != null) {
      return const PartnerPreviewScreen();
    }
    return SoloHomeScreen(uid: user.uid, profile: value);
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
