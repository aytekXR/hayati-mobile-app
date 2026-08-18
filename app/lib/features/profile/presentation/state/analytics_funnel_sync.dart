import 'package:hayati_app/core/analytics/analytics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import 'profile_providers.dart';

part 'analytics_funnel_sync.g.dart';

/// The three funnel events that are STATE TRANSITIONS rather than user actions
/// (`install`, `signup`, `paired`) — ADR-057 D4, on the `PushTokenSync` /
/// `PurchasesIdentitySync` mold: a keepAlive provider activated from the
/// always-mounted app root, reading the CURRENT state rather than only listening
/// for transitions (a listen-only design misses the value already present, which
/// on a warm start is every one of these).
///
/// **`paired` is emitted from the PROFILE, not from the join flow, and that is
/// the load-bearing choice here.** `JoinInviteController` is the obvious home
/// and it is wrong: only the **joiner** ever runs it. The **inviter** becomes
/// half of a couple without touching that controller at all, so a join-flow
/// emitter would report roughly half the pairings that happened — and Gate 2 is
/// *"pairing ≥40% of signups"*, so the metric the whole funnel exists to answer
/// would read about half its true value, with nothing anywhere reading red.
/// `users/{uid}.coupleId` is stamped server-side for **both** members, so
/// watching it catches both.
///
/// De-duplication is the emitter's (ADR-057 D4): this may re-run on every auth
/// or profile tick and the once-keys make that harmless, so nothing here needs
/// its own latch.
///
/// **Guarded, and not out of habit.** `authControllerProvider` resolves
/// `authRepositoryProvider`, which throws when unoverridden — every widget test
/// that does not wire auth. This provider is activated from `HayatiApp.build`,
/// so an unguarded throw here would take those tests down at build time. The
/// funnel degrades; the app does not (ADR-039 D1).
@Riverpod(keepAlive: true)
void analyticsFunnelSync(Ref ref) {
  final analytics = ref.read(analyticsProvider);
  // First, and outside the guard: `install` depends on nothing but the device,
  // so it must not be lost to an auth seam that is not wired.
  analytics.install();
  try {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) return;
    final uid = auth.user.uid;
    analytics.signup(uid: uid);
    final coupleId = ref.watch(profileStreamProvider(uid)).value?.coupleId;
    if (coupleId != null) {
      analytics.paired(uid: uid, coupleId: coupleId);
    }
  } on Object {
    // A funnel that cannot read the auth seam emits less; it never throws into
    // a frame.
  }
}
