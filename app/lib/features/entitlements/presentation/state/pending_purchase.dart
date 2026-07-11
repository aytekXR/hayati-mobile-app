import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'entitlement_providers.dart';

part 'pending_purchase.g.dart';

/// The durable post-purchase "processing" signal for a couple (M4.2, ADR-014
/// Decision 3). keepAlive per coupleId so it survives the autoDispose paywall
/// controller dying on route pop: in the webhook-undeployed window `isPremium`
/// never flips, and an ephemeral banner would resurrect the buy buttons on
/// re-push. Set by a completed purchase/restore ([mark]); auto-clears the moment
/// the watched mirror flips `isPremium` true. The banner renders from
/// `flag ∧ !isPremium`, so it survives rebuilds and pop/re-push for the session.
@Riverpod(keepAlive: true)
class PendingPurchase extends _$PendingPurchase {
  @override
  bool build({required String coupleId}) {
    ref.listen(isPremiumProvider(coupleId: coupleId), (_, premium) {
      if (premium) state = false;
    });
    return false;
  }

  /// Records a completed purchase/restore — the couple is now in the processing
  /// window until the mirror confirms entitlement.
  void mark() => state = true;
}
