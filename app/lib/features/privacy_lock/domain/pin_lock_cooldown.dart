/// Attempt bounding — the REAL online control on a 10⁶ PIN space (ADR-018
/// Decision 4; `pin_hasher.dart` explains why the hash is not it).
///
/// Schedule: attempts 1–4 are free; the 5th wrong attempt starts a 30s cooldown,
/// the 6th a minute, the 7th and every one after that five minutes. `wrongCount`
/// is CUMULATIVE and persisted in the Keychain record — a kill-and-relaunch is
/// not a retry reset — and only a successful unlock resets it to 0.
///
/// Cooldown honesty (Decision 4, review finding SEC-4A): against a holder who
/// never touches the device clock, ~10 attempts/hour at the 5-minute tier is
/// years for 10⁶. Against a holder who sets the clock FORWARD, each jump elapses
/// the deadline and the bound degrades to hand-entry speed on a keypad with no
/// automation surface. Stated, not hidden; there is no persistent monotonic
/// clock across process death.
library;

/// Wrong attempts that carry no cooldown (ADR-018 Decision 4).
const int kFreeWrongAttempts = 4;

/// The cooldown tier a given cumulative [wrongCount] lands in — the UI must name
/// the tier ACCURATELY (review finding DVUX-5: one "about a minute" string would
/// understate the 5-minute tier 5×, an over-claim the honest-states rule
/// forbids), so the copy is selected from this enum, never from a single string.
enum PinLockCooldownTier { thirtySeconds, oneMinute, fiveMinutes }

/// The cooldown owed AFTER the [wrongCount]-th wrong attempt, or null when the
/// attempt was free. Pure; unit-tested at every boundary.
Duration? cooldownFor(int wrongCount) => switch (wrongCount) {
  <= kFreeWrongAttempts => null,
  5 => const Duration(seconds: 30),
  6 => const Duration(minutes: 1),
  _ => const Duration(minutes: 5),
};

/// The tier of [cooldownFor], for the copy selector. Null iff no cooldown.
PinLockCooldownTier? cooldownTierFor(int wrongCount) => switch (wrongCount) {
  <= kFreeWrongAttempts => null,
  5 => PinLockCooldownTier.thirtySeconds,
  6 => PinLockCooldownTier.oneMinute,
  _ => PinLockCooldownTier.fiveMinutes,
};

/// How many further wrong attempts are free after a cumulative [wrongCount].
/// Floors at zero (a cooldown is running at that point).
int remainingBeforeCooldown(int wrongCount) =>
    (kFreeWrongAttempts - wrongCount).clamp(0, kFreeWrongAttempts);
