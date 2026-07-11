import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/entitlement_providers.dart';

/// The reusable premium gate (ADR-014 Decision 4): renders [unlocked] when the
/// couple is premium and [locked] otherwise. Every later premium feature
/// (coach at M5, quizzes at v1.5) mounts on this one seam.
///
/// Deliberately minimal: the entire premium decision stays in
/// `isPremiumProvider` (ADR-013's expiry-paired check), so this widget adds NO
/// second decision point and can never disagree with it. Loading, error, and an
/// absent mirror already collapse to `false` (free-until-proven) inside the
/// provider, so there is nothing left to decide here.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    super.key,
    required this.coupleId,
    required this.unlocked,
    required this.locked,
  });

  final String coupleId;
  final Widget unlocked;
  final Widget locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(isPremiumProvider(coupleId: coupleId)) ? unlocked : locked;
}
