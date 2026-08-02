import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_provider.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/storage/local_flag_store.dart';
import '../../../core/widgets/seed_mark.dart';
import '../../pairing/presentation/partner_preview_screen.dart';
import '../../pairing/presentation/state/pending_invite.dart';
import '../../profile/presentation/onboarding_gate.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_state.dart';
import 'ritual_preview_screen.dart';
import 'state/auth_controller.dart';
import 'state/ritual_preview_seen.dart';
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
    // The first-launch ritual preview (redesign M-5, ui-ux §5.1 step 1):
    // three swipeable cards before the sign-in ask, once per device. Ranked
    // BELOW the pending-invite branch — an invitee came for a person, not a
    // pitch (§5.3) — and only on the settled signed-out state: a session
    // restore in flight keeps its spinner, and an AuthError must surface its
    // error view, never be swallowed by the pitch.
    if (authState is AuthSignedOut) {
      ref.watch(ritualPreviewSeenProvider);
      if (!ref.read(localFlagStoreProvider).isSet(ritualPreviewSeenKey)) {
        return const RitualPreviewScreen();
      }
    }
    return Scaffold(
      body: SafeArea(
        // Centred when it fits, scrollable when it does not.
        //
        // This screen is a `Column` with no scroll view, and it just grew a
        // mark and a tagline. At 130% dynamic type on a short device the auth
        // shell — hero, three provider buttons, the Class G legal footer and
        // its two links — is the funnel's tallest surface, and the failure mode
        // of an unbounded Column is not a scrollbar, it is a yellow-and-black
        // overflow stripe with the legal footer CLIPPED. That footer is a
        // consent surface (ADR-023): it may not be the thing that falls off.
        //
        // The `minHeight: constraints.maxHeight` + `Center` pair is what keeps
        // it pixel-identical when there IS room — the goldens for the six
        // settled cells do not move because of this widget, only because of the
        // hero above.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.screenGutter,
                    vertical: SpacingTokens.x6,
                  ),
                  child: switch (authState) {
                    AuthSignedOut() => const _SignedOutView(),
                    AuthError(:final failure) => _ErrorView(failure: failure),
                    _ => const CircularProgressIndicator(),
                  },
                ),
              ),
            ),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The hero (redesign QW-5). This screen used to be the app name and
        // nothing else — a returning user's whole first impression, selling
        // nothing. It now carries the mark, the name and the promise, in that
        // order.
        //
        // The mark is decorative on purpose: the name sits directly beneath it
        // as text, so labelling the glyph too would make a screen reader say
        // the product's name twice before reaching the tagline.
        const SeedMark(),
        const SizedBox(height: SpacingTokens.x4),
        // Hero wordmark on the display role (sand — pomegranate-on-night fails
        // the >=4.5 contrast rule, so the brand text stays sand).
        Text(config.appName, style: theme.textTheme.displaySmall),
        const SizedBox(height: SpacingTokens.x2),
        // The primary tagline — the same sentence the pre-sign-in preview
        // opens with, which is the point: whichever door you came through, the
        // product introduces itself the same way. Mist (7.9:1 on Night) keeps
        // it secondary to the name rather than competing with it.
        Text(
          l10n.signInTagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
