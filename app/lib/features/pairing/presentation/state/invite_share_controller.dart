import 'package:hayati_app/core/analytics/analytics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/invite_repository_provider.dart';
import '../../domain/invite_share_launcher.dart';
import '../../domain/issued_invite.dart';

part 'invite_share_controller.g.dart';

/// Riverpod 3 auto-retry disabled (same rationale as `profileStreamProvider`):
/// a failed `createInvite` is unauthenticated, rate-limited, or a bug — none
/// self-heal on a backoff timer, and silently hammering the callable just pins
/// the screen on a spinner. Recovery is the user-driven [retry] on the error
/// view.
Duration? _noRetry(int retryCount, Object error) => null;

/// Drives the invite share screen. [build] issues the invite once (the
/// resulting `AsyncValue<IssuedInvite>` drives the three screen states, same
/// stream-consumer idiom as the OnboardingGate), [retry] re-runs it, and
/// [share] hands the composed message to the launcher seam.
///
/// autoDispose (screen-scoped like `ProfileCaptureController`): the invite is
/// issued when the screen first watches this and released when it leaves.
@Riverpod(retry: _noRetry)
class InviteShareController extends _$InviteShareController {
  /// Single-flight guard for [share]: drops re-entrant taps while a share
  /// sheet request is in flight (double-tap debounce).
  bool _sharing = false;

  @override
  Future<IssuedInvite> build() =>
      ref.watch(inviteRepositoryProvider).createInvite();

  /// Re-issues the invite after a failure (or to refresh an expiring code):
  /// invalidating self re-runs [build], moving the AsyncValue back through
  /// loading → data | error.
  void retry() => ref.invalidateSelf();

  /// Presents the platform share sheet for [message]. A no-op while a previous
  /// share is still in flight.
  Future<void> share(String message) async {
    if (_sharing) return;
    _sharing = true;
    // Captured BEFORE the await: `ref.read` on an autoDispose controller
    // THROWS once it is disposed, and this one can be disposed mid-flight —
    // its own `ref.mounted` guard below concedes exactly that. The Analytics
    // instance itself is keepAlive, so emitting through the captured handle
    // is safe from anywhere. (Found by ADR-017 D8's disposed-mid-send test,
    // which is the only place the repo already exercised this; the other
    // three call sites had the same latent defect and no test to reveal it.)
    final analytics = ref.read(analyticsProvider);
    try {
      await ref.read(inviteShareLauncherProvider).shareText(message);
      // `invite_sent` (architecture.md §7) AFTER the launcher returns, so a
      // share sheet that never opened is not counted as an invite. Per action,
      // not de-duplicated: a user who shares twice sent two invites (ADR-057
      // D4). The single-flight guard above already drops a double tap.
      analytics.inviteSent();
    } finally {
      if (ref.mounted) _sharing = false;
    }
  }
}
