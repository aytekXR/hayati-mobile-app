import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/storage/local_flag_store.dart';
import '../../auth/domain/auth_user.dart';
import '../../daily_question/presentation/paired_home_screen.dart';
import '../../daily_question/presentation/solo_home_screen.dart';
import '../../data_rights/presentation/couple_ended_notice_screen.dart';
import '../../data_rights/presentation/state/couple_ended_seen.dart';
import '../../legal/domain/consent_status.dart';
import '../../legal/presentation/consent_gate_screen.dart';
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
///  2. !hasCurrentConsent(profile) → the special-category consent gate
///     (ADR-023 D3), evaluated immediately after capture and BEFORE every home
///     and notice: profile fields (status/contentLanguage/register) are ordinary
///     contract-basis data needed to render the gate in the right language and
///     register, but the reflective content the gate protects begins at the
///     homes, so consent is a precondition on all of them;
///  3. profile.coupleId != null   → the paired home (M3 slot) — the terminal
///     state wins over everything, so a just-joined user re-routes here the
///     moment `joinInvite` stamps the couple, whichever screen they came from;
///  4. coupleId == null && coupleEndedAt != null && !seen → the honest terminal
///     notice (ADR-019 D3), evaluated BEFORE the pending-invite branch (review
///     finding NOTICE-2 — a joiner arriving by deep link with `coupleEnded` set
///     must see the notice first; the invite flow continues after Continue);
///  5. pendingInvite != null      → the partner preview / join screen — an
///     onboarded-but-solo user who arrived on a `hayati://invite/<code>` link
///     sees who invited them and can accept;
///  6. otherwise                  → the solo home (M2.4): the day-N solo
///     reflection question with the persistent invite nudge — the share flow
///     stays one tap away behind the nudge.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileStreamProvider(user.uid));
    // Subscribe so acknowledging the couple-ended notice (which bumps this
    // provider after writing the durable seen flag) re-evaluates the gate
    // reactively (review finding APP-2). No override needed — it seeds to 0.
    ref.watch(coupleEndedSeenProvider);
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
    // The special-category consent gate (ADR-023 D3): evaluated immediately
    // after capture and BEFORE every home/notice branch. `hasCurrentConsent` is
    // fail-closed (a null/junk/stale-version consent gates), so this holds the
    // reflective surfaces until the server-stamped consent arrives on the stream.
    if (!hasCurrentConsent(value)) {
      return ConsentGateScreen(uid: user.uid);
    }
    // coupleId (paired) beats a still-pending invite: once paired, the invite
    // is spent and the pending code is stale.
    final coupleId = value.coupleId;
    if (coupleId != null) {
      return PairedHomeScreen(uid: user.uid, coupleId: coupleId);
    }
    // The honest terminal notice (ADR-019 D3): a member whose couple was ended by
    // the partner's cascade deletion — coupleId cleared, coupleEnded stamped —
    // sees this ONCE per event before anything else routes them silently to solo.
    // Evaluated ABOVE the pending-invite branch (NOTICE-2). The seen flag is
    // event-keyed (by the `at`), so a SECOND ending after a re-pair shows again.
    final coupleEndedAt = value.coupleEndedAt;
    if (coupleEndedAt != null &&
        !ref
            .read(localFlagStoreProvider)
            .isSet(coupleEndedSeenKey(user.uid, coupleEndedAt))) {
      return CoupleEndedNoticeScreen(
        uid: user.uid,
        coupleEndedAt: coupleEndedAt,
      );
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
