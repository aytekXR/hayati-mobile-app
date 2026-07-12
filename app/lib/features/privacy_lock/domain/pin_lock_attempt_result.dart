import 'pin_lock_cooldown.dart';

/// The verdict of one PIN attempt (ADR-018 Decision 4). Sealed, value-equal, and
/// — the no-content rule — carrying COUNTS and DEADLINES only: no PIN digit, no
/// hash, no salt ever reaches a `toString()` that the Crashlytics hooks could
/// forward.
///
/// Write ordering is pinned upstream (review finding SEC-4B): a wrong attempt's
/// incremented record is persisted — AWAITED — before any of these is returned,
/// so a kill between keypress and verdict lands on the incremented side.
sealed class PinLockAttemptResult {
  const PinLockAttemptResult();
}

/// The PIN was correct: the counter is reset and the app is unlocked.
final class PinLockAttemptAccepted extends PinLockAttemptResult {
  const PinLockAttemptAccepted();

  @override
  bool operator ==(Object other) => other is PinLockAttemptAccepted;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'PinLockAttemptAccepted()';
}

/// The PIN was wrong. [remainingBeforeCooldown] is how many further wrong
/// attempts are still free; [cooldownUntilMs] / [tier] are non-null iff THIS
/// attempt started a cooldown (the tier drives the tier-accurate copy — DVUX-5).
final class PinLockAttemptWrong extends PinLockAttemptResult {
  const PinLockAttemptWrong({
    required this.remainingBeforeCooldown,
    this.cooldownUntilMs,
    this.tier,
  });

  final int remainingBeforeCooldown;
  final int? cooldownUntilMs;
  final PinLockCooldownTier? tier;

  @override
  bool operator ==(Object other) =>
      other is PinLockAttemptWrong &&
      other.remainingBeforeCooldown == remainingBeforeCooldown &&
      other.cooldownUntilMs == cooldownUntilMs &&
      other.tier == tier;

  @override
  int get hashCode =>
      Object.hash(remainingBeforeCooldown, cooldownUntilMs, tier);

  @override
  String toString() =>
      'PinLockAttemptWrong(remainingBeforeCooldown: $remainingBeforeCooldown, '
      'cooldownUntilMs: $cooldownUntilMs, tier: $tier)';
}

/// A cooldown is running — the attempt was REFUSED and is NOT consumed (it never
/// reaches the hash compare, so it cannot advance the counter).
final class PinLockAttemptCooldown extends PinLockAttemptResult {
  const PinLockAttemptCooldown({required this.cooldownUntilMs, this.tier});

  final int cooldownUntilMs;
  final PinLockCooldownTier? tier;

  @override
  bool operator ==(Object other) =>
      other is PinLockAttemptCooldown &&
      other.cooldownUntilMs == cooldownUntilMs &&
      other.tier == tier;

  @override
  int get hashCode => Object.hash(cooldownUntilMs, tier);

  @override
  String toString() =>
      'PinLockAttemptCooldown(cooldownUntilMs: $cooldownUntilMs, tier: $tier)';
}

/// No verdict was produced: either the attempt was dropped as re-entrant (the
/// repo's manual-op discipline) or the lock was WIPED mid-flight by the sign-out
/// path — the generation guard aborted it (ADR-018 Decision 1). Nothing was
/// written and nothing was decided; the UI has nothing honest to say, and by the
/// time it could, the overlay is gone.
final class PinLockAttemptAborted extends PinLockAttemptResult {
  const PinLockAttemptAborted();

  @override
  bool operator ==(Object other) => other is PinLockAttemptAborted;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'PinLockAttemptAborted()';
}
