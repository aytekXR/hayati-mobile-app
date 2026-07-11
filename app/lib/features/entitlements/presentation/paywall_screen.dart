import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/design_system/color_tokens.dart';
import '../../../core/design_system/radius_tokens.dart';
import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/state/auth_controller.dart';
import '../domain/paywall_offering.dart';
import '../domain/purchase_exception.dart';
import 'state/entitlement_providers.dart';
import 'state/paywall_providers.dart';
import 'state/paywall_purchase_controller.dart';
import 'state/pending_purchase.dart';

/// Pushes the paywall over the current route — the single entry point every
/// gate uses (ADR-014 Decision 3). Couple-scoped by signature: a [coupleId]
/// exists only post-join, so an unpaired user can never reach a buy button.
Future<void> showPaywall(BuildContext context, {required String coupleId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PaywallScreen(coupleId: coupleId)),
  );
}

/// The paywall (PRD F4, ADR-014 Decision 3): annual-first cards, trial
/// messaging, one-purchase-covers-both, store-localized prices (never
/// hardcoded). The mirror is the only unlocker — a completed purchase renders a
/// processing banner and flips to the entitled view only when `isPremium` flips
/// from the watched `subscriptions/{coupleId}` mirror.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth-loss self-pop (the `_PushedInviteShare` Session-010 idiom):
    // `OnboardingGate` swaps only the home widget, so a remote sign-out would
    // strand the user on this pushed route over the auth shell.
    ref.listen(authControllerProvider, (previous, next) {
      if (next is! AuthSignedIn) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    // Entitled first: an already-premium couple never sees buy buttons.
    if (ref.watch(isPremiumProvider(coupleId: coupleId))) {
      return _EntitledView(coupleId: coupleId);
    }

    // Free → offerings fetch, the AsyncValue-flag precedence idiom (not the
    // subtype; Riverpod 3 carries a previous error/value across states).
    final offering = ref.watch(paywallOfferingProvider);
    if (offering.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final error = offering.error;
    if (error != null) {
      return _PaywallErrorView(
        error: error,
        onRetry: () => ref.invalidate(paywallOfferingProvider),
      );
    }
    return _PaywallLoadedView(coupleId: coupleId, offering: offering.value!);
  }
}

/// The already-premium view: confirmation copy, a restore action, and a
/// "manage in your store" caption — no buy buttons (ADR-014 Decision 3). A
/// single small gold premium mark is the only gold on the screen (restraint
/// reads premium).
class _EntitledView extends ConsumerWidget {
  const _EntitledView({required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final purchaseState = ref.watch(
      paywallPurchaseControllerProvider(coupleId: coupleId),
    );
    final inFlight = purchaseState is PaywallPurchaseInFlight;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
              vertical: SpacingTokens.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The one restrained gold accent (premium mark).
                const Icon(
                  Icons.workspace_premium,
                  color: ColorTokens.gold,
                  size: 40,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.paywallEntitledTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.paywallEntitledBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x6),
                TextButton(
                  onPressed: inFlight
                      ? null
                      : () => ref
                            .read(
                              paywallPurchaseControllerProvider(
                                coupleId: coupleId,
                              ).notifier,
                            )
                            .restore(),
                  child: Text(l10n.paywallRestore),
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.paywallManageHint,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The loaded free view: annual-first cards, a selectable primary CTA, the
/// one-purchase-covers-both pitch, the honest free-tier note, and a restore
/// text button. The selected package drives the CTA (default = the first /
/// annual package).
class _PaywallLoadedView extends ConsumerStatefulWidget {
  const _PaywallLoadedView({required this.coupleId, required this.offering});

  final String coupleId;
  final PaywallOffering offering;

  @override
  ConsumerState<_PaywallLoadedView> createState() => _PaywallLoadedViewState();
}

class _PaywallLoadedViewState extends ConsumerState<_PaywallLoadedView> {
  int _selected = 0;

  /// The kind of the last op the user launched. Selects the processing banner
  /// copy for THIS session: the durable pending-purchase flag is a bool by
  /// design (the mirror is the only unlocker), so a re-pushed screen — where
  /// this is null — honestly falls back to the generic purchase copy.
  PaywallPurchaseKind? _lastRequestedKind;

  void _purchase() {
    setState(() => _lastRequestedKind = PaywallPurchaseKind.purchase);
    ref
        .read(
          paywallPurchaseControllerProvider(coupleId: widget.coupleId).notifier,
        )
        .purchase(widget.offering.packages[_selected].package);
  }

  void _restore() {
    setState(() => _lastRequestedKind = PaywallPurchaseKind.restore);
    ref
        .read(
          paywallPurchaseControllerProvider(coupleId: widget.coupleId).notifier,
        )
        .restore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final packages = widget.offering.packages;
    final selected = packages[_selected];
    final purchaseState = ref.watch(
      paywallPurchaseControllerProvider(coupleId: widget.coupleId),
    );
    final inFlight = purchaseState is PaywallPurchaseInFlight;
    // The reachable branch here is already `!isPremium` (the screen returns the
    // entitled view otherwise), so the flag alone is `flag ∧ !isPremium`.
    final processing = ref.watch(
      pendingPurchaseProvider(coupleId: widget.coupleId),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenGutter,
              vertical: SpacingTokens.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (processing) ...[
                  _ProcessingBanner(
                    text: _lastRequestedKind == PaywallPurchaseKind.restore
                        ? l10n.paywallRestoreProcessing
                        : l10n.paywallProcessing,
                  ),
                  const SizedBox(height: SpacingTokens.x6),
                ],
                Text(
                  l10n.paywallTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.paywallPitch,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x6),
                for (var i = 0; i < packages.length; i++) ...[
                  _PackageCard(
                    package: packages[i],
                    selected: i == _selected,
                    primary: i == 0,
                    onTap: inFlight
                        ? null
                        : () => setState(() => _selected = i),
                  ),
                  const SizedBox(height: SpacingTokens.x3),
                ],
                const SizedBox(height: SpacingTokens.x3),
                if (purchaseState is PaywallPurchaseFailure) ...[
                  _PurchaseFailureCard(
                    text: _purchaseExceptionCopy(l10n, purchaseState.exception),
                    onDismiss: () => ref
                        .read(
                          paywallPurchaseControllerProvider(
                            coupleId: widget.coupleId,
                          ).notifier,
                        )
                        .dismissError(),
                  ),
                  const SizedBox(height: SpacingTokens.x3),
                ],
                if (inFlight)
                  const FilledButton(
                    onPressed: null,
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: _purchase,
                    child: Text(
                      selected.trial != null
                          ? l10n.paywallCtaTrial
                          : l10n.paywallCta,
                    ),
                  ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.paywallFreeNote,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.x2),
                TextButton(
                  onPressed: inFlight ? null : _restore,
                  child: Text(l10n.paywallRestore),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One purchasable package as a selectable card. The first (annual) package is
/// visually primary — a pomegranate selected border plus the restrained gold
/// best-value badge; the verbatim price string is prominent and never
/// re-formatted.
class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final PaywallPackage package;
  final bool selected;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final periodLabel = switch (package.packageType) {
      PackageType.annual => l10n.paywallPerYear,
      PackageType.monthly => l10n.paywallPerMonth,
      // Honest fallback: an unknown period renders only the verbatim price.
      _ => null,
    };
    final trialLabel = _trialLabel(l10n, package.trial);
    return InkWell(
      onTap: onTap,
      borderRadius: RadiusTokens.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.cardPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: RadiusTokens.cardRadius,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (primary) ...[
              _BestValueBadge(label: l10n.paywallBestValue),
              const SizedBox(height: SpacingTokens.x2),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(package.priceString, style: theme.textTheme.titleLarge),
                if (periodLabel != null) ...[
                  const SizedBox(width: SpacingTokens.x1),
                  Text(periodLabel, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
            if (package.pricePerMonthString != null) ...[
              const SizedBox(height: SpacingTokens.x1),
              Text(
                l10n.paywallApproxPerMonth(package.pricePerMonthString!),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (trialLabel != null) ...[
              const SizedBox(height: SpacingTokens.x2),
              Text(
                trialLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A day-count trial renders the plural line; any other unit renders the
  /// honest count-less fallback (ADR-014 Decision 3 — StoreKit may report a
  /// 7-day trial as WEEK/1, pinned at the M4.3 sandbox smoke).
  static String? _trialLabel(AppLocalizations l10n, PaywallTrial? trial) {
    if (trial == null) return null;
    final count = trial.count;
    if (count != null && trial.unit == PeriodUnit.day) {
      return l10n.paywallTrialDays(count);
    }
    return l10n.paywallTrialGeneric;
  }
}

/// The restrained gold best-value badge (premium accent only).
class _BestValueBadge extends StatelessWidget {
  const _BestValueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.x3,
        vertical: SpacingTokens.x1,
      ),
      decoration: const BoxDecoration(
        color: ColorTokens.gold,
        borderRadius: BorderRadius.all(Radius.circular(RadiusTokens.card)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: ColorTokens.night),
      ),
    );
  }
}

/// The durable post-purchase banner: good news, not an alert — a raised surface
/// with a sage accent, never the error colour (ADR-014 Decision 3).
class _ProcessingBanner extends StatelessWidget {
  const _ProcessingBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: RadiusTokens.cardRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: theme.colorScheme.tertiary),
          const SizedBox(width: SpacingTokens.x3),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// A dismissable inline purchase-failure surface (the solo/paired save-error
/// idiom, in the theme's alert colour).
class _PurchaseFailureCard extends StatelessWidget {
  const _PurchaseFailureCard({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: RadiusTokens.cardRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: SpacingTokens.x3),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
            color: theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}

/// The offerings-fetch error state: typed network-retry vs unavailable copy,
/// with a retry that re-fetches (`ref.invalidate`).
class _PaywallErrorView extends StatelessWidget {
  const _PaywallErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detail = error is PurchaseException
        ? _purchaseExceptionCopy(l10n, error as PurchaseException)
        : l10n.errorGeneric;
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

/// Maps a purchases-taxonomy exception to l10n copy, reusing the house
/// network/generic keys (ADR-014 Decision 3): network → retry advice,
/// unavailable/unconfigured → the honest store-unavailable line, else generic.
String _purchaseExceptionCopy(AppLocalizations l10n, PurchaseException error) {
  return switch (error) {
    PurchaseNetworkException() => l10n.errorNetworkRetry,
    PaywallUnavailableException() ||
    PurchasesUnavailableException() => l10n.paywallUnavailable,
    _ => l10n.errorGeneric,
  };
}
