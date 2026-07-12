import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'couple_ended_seen.g.dart';

/// The device-local "seen" flag key for a partner morning-after notice (ADR-019
/// Decision 3), keyed by the EVENT (`uid` + the `coupleEnded.at` epoch-ms), not
/// just the user: a single set-once flag on the never-cleared [LocalFlagStore]
/// would swallow the notice for a SECOND `coupleEnded` after a re-pair (review
/// findings NOTICE-1 / DV-1-app — the exact wordless vanish the notice exists to
/// prevent). A new ending has a different `at`, so it mints a fresh key and is
/// noticed exactly once per device; per-uid keying keeps the flag from leaking
/// across accounts on a shared device (the coach-ack precedent).
String coupleEndedSeenKey(String uid, DateTime at) =>
    'coupleEndedSeen.$uid.${at.millisecondsSinceEpoch}';

/// A tiny keepAlive notifier the onboarding gate watches so that acknowledging a
/// notice re-evaluates the gate reactively (review finding APP-2, pinned as
/// mechanism, not left to "the gate notices"). The gate reads the durable flag
/// off [LocalFlagStore] synchronously; this provider only carries the CHANGE
/// signal — [markSeen] bumps a version after the durable flag is written, and the
/// gate's `watch` re-runs against the now-set flag, dropping the notice.
@Riverpod(keepAlive: true)
class CoupleEndedSeen extends _$CoupleEndedSeen {
  @override
  int build() => 0;

  /// Bumps the version — call AFTER the durable [LocalFlagStore] write completes.
  void markSeen() => state = state + 1;
}
