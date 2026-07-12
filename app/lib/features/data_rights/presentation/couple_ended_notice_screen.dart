import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/spacing_tokens.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/storage/local_flag_store.dart';
import 'state/couple_ended_seen.dart';

/// B's morning-after: the honest terminal notice rendered when the partner's
/// cascade deletion ended this member's couple (ADR-019 Decision 3). It is
/// rendered BY the onboarding gate as a gate child — never a pushed route — so it
/// cannot be popped back to (review finding APP-2). The copy attributes NO actor
/// (review finding DV-2): the shared space "has been closed", not "your partner
/// deleted it". Only A could have done it and B will usually know, but the app
/// does not say it — that reticence is deliberate and recorded.
///
/// The single "Continue" action writes the EVENT-keyed seen flag to
/// [LocalFlagStore] (so a SECOND `coupleEnded` after a re-pair — necessarily a
/// different `at` — is noticed again) and then bumps [coupleEndedSeenProvider],
/// whose change re-evaluates the gate: the durable flag is now set, so the gate
/// drops the notice and routes on to the solo home (or a pending invite).
class CoupleEndedNoticeScreen extends ConsumerWidget {
  const CoupleEndedNoticeScreen({
    super.key,
    required this.uid,
    required this.coupleEndedAt,
  });

  final String uid;
  final DateTime coupleEndedAt;

  Future<void> _acknowledge(WidgetRef ref) async {
    final key = coupleEndedSeenKey(uid, coupleEndedAt);
    // Durable write FIRST, then the reactive bump — so when the gate re-evaluates
    // it reads the now-set flag and never re-shows the notice.
    await ref.read(localFlagStoreProvider).set(key);
    ref.read(coupleEndedSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.coupleEndedTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: SpacingTokens.x5),
                Text(l10n.coupleEndedBody, style: theme.textTheme.bodyMedium),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.coupleEndedReflections,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.coupleEndedSubscription,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: SpacingTokens.x3),
                Text(
                  l10n.coupleEndedPairAgain,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: SpacingTokens.x8),
                FilledButton(
                  onPressed: () => _acknowledge(ref),
                  child: Text(l10n.coupleEndedContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
