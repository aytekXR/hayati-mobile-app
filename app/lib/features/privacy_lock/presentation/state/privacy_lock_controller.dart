import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/pin_lock_store.dart';
import '../../../daily_question/domain/solo_clock.dart';
import '../../domain/biometric_authenticator.dart';
import '../../domain/pin_hasher.dart';
import '../../domain/pin_lock_attempt_result.dart';
import '../../domain/pin_lock_cooldown.dart';

part 'privacy_lock_controller.g.dart';

/// The background grace window (ADR-018 Decision 3): a return within 60s of the
/// app being PAUSED or HIDDEN does not re-lock. Sized for the real flow —
/// switching to Messages to paste an invite code and coming back. `.inactive`
/// (control centre, permission sheets, the share sheet, the biometric prompt
/// itself) does NOT start this clock; it only raises the shield. In-memory only,
/// so a cold start ALWAYS locks.
const Duration kLockGraceWindow = Duration(seconds: 60);

/// The lock gate's state (ADR-018 Decision 3). Sealed, value-equal, and — the
/// no-content rule (architecture §8) — carrying only booleans and a deadline:
/// no PIN, salt, hash, or enrollment byte may ever reach a `toString()` the
/// Crashlytics hooks could forward.
sealed class PrivacyLockState {
  const PrivacyLockState();
}

/// No PIN is set on this device: the gate renders nothing.
final class PrivacyLockDisabled extends PrivacyLockState {
  const PrivacyLockDisabled();

  @override
  bool operator ==(Object other) => other is PrivacyLockDisabled;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'PrivacyLockDisabled()';
}

/// A PIN is set and this session is NOT authenticated — the overlay is up.
final class PrivacyLocked extends PrivacyLockState {
  const PrivacyLocked({
    this.lockoutUntilMs,
    this.biometricRevoked = false,
    this.biometricAvailable = false,
  });

  /// Wall-clock deadline (ms) before which attempts are refused, or null.
  final int? lockoutUntilMs;

  /// The biometric accelerator was just AUTO-REVOKED because the platform's
  /// enrollment state changed (or went unavailable) — the lock screen shows the
  /// honest one-liner and requires the PIN (ADR-018 Decision 1, review finding
  /// DVUX-1).
  final bool biometricRevoked;

  /// Whether the lock screen may offer the biometric button right now (enabled in
  /// the record AND currently available on the device).
  final bool biometricAvailable;

  @override
  bool operator ==(Object other) =>
      other is PrivacyLocked &&
      other.lockoutUntilMs == lockoutUntilMs &&
      other.biometricRevoked == biometricRevoked &&
      other.biometricAvailable == biometricAvailable;

  @override
  int get hashCode =>
      Object.hash(lockoutUntilMs, biometricRevoked, biometricAvailable);

  @override
  String toString() =>
      'PrivacyLocked(lockoutUntilMs: $lockoutUntilMs, '
      'biometricRevoked: $biometricRevoked, '
      'biometricAvailable: $biometricAvailable)';
}

/// A PIN is set and this session IS authenticated — the app is visible.
final class PrivacyLockUnlocked extends PrivacyLockState {
  const PrivacyLockUnlocked();

  @override
  bool operator ==(Object other) => other is PrivacyLockUnlocked;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'PrivacyLockUnlocked()';
}

/// The device-lock state machine (ADR-018 Decisions 1/2/3/4) — the security core
/// of the privacy layer. `keepAlive`: the gate is mounted for the process's whole
/// life and its state must survive every route change.
///
/// [build] seeds SYNCHRONOUSLY from the boot snapshot (Decision 2): the gate must
/// decide the FIRST frame — an async check would flash couple content, and the
/// OS would snapshot that flash. No spinner, no async in build.
///
/// TWO invariants a future editor must not break:
///
/// * **The generation guard (Decision 1; blocking review finding FLUTTER-3 — the
///   S019 race class).** `_generation` is bumped by [wipe] BEFORE the store is
///   cleared. EVERY mutating op captures it at entry and re-checks it after EVERY
///   await — before every store write and before every state assignment — and
///   aborts on mismatch. `ref.mounted` CANNOT carry this: this controller is
///   keepAlive and is wiped IN PLACE, never disposed, so `ref.mounted` stays true
///   while a wrong-attempt persist (or a post-biometric write) races the sign-out
///   wipe. Without the guard, that write re-persists the previous user's
///   `pinHash` after the clear — the next user inherits their lock.
/// * **[wipe] never invalidates this provider (Decision 1; review finding
///   FLUTTER-2).** See the loud comment there.
@Riverpod(keepAlive: true)
class PrivacyLockController extends _$PrivacyLockController {
  /// The in-process mirror of the persisted record. Source of truth for every
  /// decision inside the process; the store is the source of truth across
  /// launches.
  PinLockRecord? _record;

  /// Bumped by [wipe]. Every mutating op captures it at entry — see the class
  /// doc. Monotonic; never reset.
  int _generation = 0;

  /// The repo's manual-op discipline: a re-entrant op is DROPPED while one is in
  /// flight. [wipe] is deliberately exempt — teardown must never be droppable.
  bool _busy = false;

  /// Set on `paused`/`hidden` (the widget decides; `.inactive` must NOT reach
  /// here — Decision 3). First stamp wins, so the hidden→paused pair that iOS
  /// fires keeps the EARLIER instant (the conservative one).
  int? _backgroundedAtMs;

  /// The degraded-boot reconcile (Decision 2; review finding SEC-3): a boot read
  /// that THREW fails open for exactly one launch, and the first `resumed`
  /// re-reads the store once. Consumed on that first attempt, success or not.
  bool _degradedReconcilePending = false;

  @override
  PrivacyLockState build() {
    final snapshot = ref.read(initialLockSnapshotProvider);
    _record = snapshot.record;
    _degradedReconcilePending = snapshot.degraded;

    final record = snapshot.record;
    // Cold start ALWAYS locks when a record exists: the grace window is in-memory
    // only (Decision 3), so a killed-and-relaunched app is never "still in grace".
    if (record != null && record.isSet) {
      return PrivacyLocked(lockoutUntilMs: record.lockoutUntilMs);
    }
    return const PrivacyLockDisabled();
  }

  PinLockStore get _store => ref.read(pinLockStoreProvider);

  int get _nowMs => ref.read(soloClockProvider)().millisecondsSinceEpoch;

  /// The active cooldown deadline, or null when none is running.
  int? _activeCooldown(int nowMs) {
    final until = _record?.lockoutUntilMs;
    if (until == null || nowMs >= until) return null;
    return until;
  }

  /// Verifies a PIN attempt (Decisions 1/4).
  ///
  /// Write ordering is PINNED (review finding SEC-4B): on a wrong attempt the
  /// incremented record is persisted — AWAITED — BEFORE the verdict is returned,
  /// so a kill in the window between keypress and acknowledgement lands on the
  /// incremented side, never the free side. A restart is not a retry reset.
  Future<PinLockAttemptResult> verifyPin(String pin) async {
    if (_busy) return const PinLockAttemptAborted();
    final record = _record;
    if (record == null || !record.isSet) return const PinLockAttemptAborted();

    final gen = _generation;
    _busy = true;
    try {
      final now = _nowMs;
      final cooldownUntil = _activeCooldown(now);
      if (cooldownUntil != null) {
        // Refused, NOT consumed: the attempt never reaches the compare, so it
        // cannot advance the counter (Decision 4).
        return PinLockAttemptCooldown(
          cooldownUntilMs: cooldownUntil,
          tier: cooldownTierFor(record.wrongCount),
        );
      }

      if (constantTimeEquals(hashPin(pin: pin, salt: record.salt),
          record.pinHash)) {
        final reset = record.copyWith(wrongCount: 0, lockoutUntilMs: null);
        if (gen != _generation) return const PinLockAttemptAborted();
        // In-memory FIRST, then the awaited write (see the wrong-attempt path
        // below for why the ordering matters).
        _record = reset;
        await _writeQuietly(reset);
        if (gen != _generation) return const PinLockAttemptAborted();
        state = const PrivacyLockUnlocked();
        return const PinLockAttemptAccepted();
      }

      final wrongCount = record.wrongCount + 1;
      final cooldown = cooldownFor(wrongCount);
      final lockoutUntilMs = cooldown == null
          ? null
          : now + cooldown.inMilliseconds;
      final incremented = record.copyWith(
        wrongCount: wrongCount,
        lockoutUntilMs: lockoutUntilMs,
      );

      if (gen != _generation) return const PinLockAttemptAborted();
      // The in-memory record is advanced BEFORE the await, not after it. Any
      // concurrent op that re-bases on `_record` mid-write (the un-busy-guarded
      // [refreshBiometricAvailability] is the live one) must see the CONSUMED
      // attempt — otherwise its own write, built on the pre-increment capture,
      // silently hands the attempt back and the bounding of Decision 4 becomes
      // an oracle a partner can reset at will. The write is still AWAITED before
      // the verdict returns, so the SEC-4B ordering guarantee is untouched.
      _record = incremented;
      await _writeQuietly(incremented);
      if (gen != _generation) return const PinLockAttemptAborted();

      // Carry the biometric flags forward: a wrong keypress must not make the
      // Face ID button vanish from the lock screen mid-attempt.
      final current = state;
      state = PrivacyLocked(
        lockoutUntilMs: lockoutUntilMs,
        biometricRevoked:
            current is PrivacyLocked && current.biometricRevoked,
        biometricAvailable:
            current is PrivacyLocked && current.biometricAvailable,
      );
      return PinLockAttemptWrong(
        remainingBeforeCooldown: remainingBeforeCooldown(wrongCount),
        cooldownUntilMs: lockoutUntilMs,
        tier: cooldownTierFor(wrongCount),
      );
    } finally {
      _busy = false;
    }
  }

  /// Biometric unlock (Decision 1). Only when the accelerator is enabled AND the
  /// platform's enrollment state still MATCHES the one captured at enable time —
  /// a mismatch auto-revokes instead of authenticating (a partner who added their
  /// face after enable gains nothing).
  ///
  /// A biometric failure is NOT a PIN attempt: it consumes no attempt and starts
  /// no cooldown. It simply leaves the keypad up.
  ///
  /// [reason] is the localized prompt string — l10n stays in the widget layer.
  Future<bool> authenticateBiometric({required String reason}) async {
    if (_busy) return false;
    final record = _record;
    if (record == null || !record.isSet || !record.biometricEnabled) {
      return false;
    }

    final gen = _generation;
    _busy = true;
    try {
      final authenticator = ref.read(biometricAuthenticatorProvider);
      final enrollment = await authenticator.enrollmentState();
      if (gen != _generation) return false;
      if (enrollment == null ||
          enrollment != record.biometricEnrollmentState) {
        await _revokeBiometric(gen);
        return false;
      }

      final ok = await authenticator.authenticate(reason: reason);
      if (gen != _generation) return false;
      if (!ok) return false;

      final reset = record.copyWith(wrongCount: 0, lockoutUntilMs: null);
      await _writeQuietly(reset);
      if (gen != _generation) return false;
      _record = reset;
      state = const PrivacyLockUnlocked();
      return true;
    } finally {
      _busy = false;
    }
  }

  /// Called when the lock screen mounts (Decision 1). Refreshes whether the
  /// biometric button may be offered — and AUTO-REVOKES the accelerator when the
  /// platform's enrollment state has changed or gone unavailable (review finding
  /// DVUX-1). Revocation rewrites the record with biometric off; re-enabling
  /// needs the PIN plus the DV warning again.
  Future<void> refreshBiometricAvailability() async {
    if (_record == null || !_record!.isSet) return;

    final gen = _generation;
    final authenticator = ref.read(biometricAuthenticatorProvider);
    final available = await authenticator.isAvailable();
    if (gen != _generation) return;
    final enrollment = await authenticator.enrollmentState();
    if (gen != _generation) return;

    // Re-read AFTER the probes: a wrong-PIN persist may have advanced the record
    // while they were in flight (this op is deliberately not `_busy`-guarded —
    // see [_revokeBiometric]).
    final record = _record;
    if (record == null || !record.isSet) return;

    if (record.biometricEnabled &&
        (!available ||
            enrollment == null ||
            enrollment != record.biometricEnrollmentState)) {
      await _revokeBiometric(gen);
      return;
    }

    final current = state;
    if (current is PrivacyLocked) {
      state = PrivacyLocked(
        lockoutUntilMs: current.lockoutUntilMs,
        biometricRevoked: current.biometricRevoked,
        biometricAvailable: available && record.biometricEnabled,
      );
    }
  }

  /// Enables the lock from settings (Decision 1): fresh salt, hashed PIN,
  /// biometric off.
  ///
  /// The caller is standing INSIDE the settings screen, already past the gate, so
  /// success leaves this session [PrivacyLockUnlocked] — locking here would lock
  /// the user out of the screen they are standing on. The lock engages on the
  /// next cold start or past-grace background return.
  ///
  /// Returns false — and leaves the state untouched — if the write FAILS: never
  /// report protection that did not persist (Decision 8's row).
  Future<bool> enableLock(String pin) async {
    if (_busy) return false;
    final gen = _generation;
    _busy = true;
    try {
      final salt = generateSalt();
      final record = PinLockRecord(
        salt: salt,
        pinHash: hashPin(pin: pin, salt: salt),
        biometricEnabled: false,
        wrongCount: 0,
      );
      if (gen != _generation) return false;
      await _store.write(record);
      if (gen != _generation) return false;
      _record = record;
      state = const PrivacyLockUnlocked();
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Turns the lock off from settings (Decision 1) — the PIN is verified first,
  /// in constant time. A WRONG PIN here counts as a wrong attempt and is
  /// persisted: the same bounding as the lock screen, or "disable" would be an
  /// unbounded oracle. A running cooldown refuses without consuming an attempt.
  Future<bool> disableLock(String pin) async {
    if (_busy) return false;
    final record = _record;
    if (record == null || !record.isSet) return false;

    final gen = _generation;
    _busy = true;
    try {
      final now = _nowMs;
      if (_activeCooldown(now) != null) return false;

      if (!constantTimeEquals(
        hashPin(pin: pin, salt: record.salt),
        record.pinHash,
      )) {
        await _persistWrongAttempt(record, gen, now);
        return false;
      }

      if (gen != _generation) return false;
      await _store.clear();
      if (gen != _generation) return false;
      _record = null;
      _backgroundedAtMs = null;
      state = const PrivacyLockDisabled();
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Toggles the biometric accelerator from settings (Decision 1). Enabling
  /// CAPTURES the platform's current enrollment state into the record (the input
  /// to the revocation check); disabling nulls it.
  ///
  /// Returns false when the platform has no enrollment state to capture (nothing
  /// enrolled / unavailable) or when the write fails — never claim an accelerator
  /// we could not persist or could not later validate.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (_busy) return false;
    final record = _record;
    if (record == null || !record.isSet) return false;

    final gen = _generation;
    _busy = true;
    try {
      PinLockRecord updated;
      if (enabled) {
        final enrollment = await ref
            .read(biometricAuthenticatorProvider)
            .enrollmentState();
        if (gen != _generation) return false;
        if (enrollment == null) return false;
        updated = record.copyWith(
          biometricEnabled: true,
          biometricEnrollmentState: enrollment,
        );
      } else {
        updated = record.copyWith(
          biometricEnabled: false,
          biometricEnrollmentState: null,
        );
      }

      if (gen != _generation) return false;
      await _store.write(updated);
      if (gen != _generation) return false;
      _record = updated;
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  /// The sign-out wipe (Decision 1) — the lock is device-scoped and dies with the
  /// session: a signed-out app shows only the sign-in screen (nothing to
  /// protect), and a next user must not inherit the previous user's PIN.
  ///
  /// LOUD RULE — the wipe is `store.clear()` plus an IN-PLACE state mutation, and
  /// **no code path may ever `ref.invalidate` this controller** (review finding
  /// FLUTTER-2). This provider is keepAlive and seeded from the BY-VALUE boot
  /// snapshot, so invalidation would re-run [build] against that STALE snapshot
  /// and replay boot state — re-locking after a wipe, or silently reverting a
  /// just-enabled lock to the boot-time `null`. This is a deliberate asymmetry
  /// with the coach listener's `ref.invalidate(coachTranscriptProvider)`: that
  /// family's `build()` returns a safe empty state; this one replays boot.
  ///
  /// The state flips SYNCHRONOUSLY (before the first await) and the generation is
  /// bumped BEFORE the clear, so every in-flight mutating op is already stale and
  /// will abort rather than re-persist the wiped record.
  Future<void> wipe() async {
    _generation++;
    _record = null;
    _backgroundedAtMs = null;
    _degradedReconcilePending = false;
    state = const PrivacyLockDisabled();
    try {
      await _store.clear();
    } catch (_) {
      // An orphaned record is escapable, not a brick (Decision 8): the overlay is
      // state-driven, and the lock screen's recovery action is idempotent.
    }
  }

  /// Stamps the start of the grace window. Called ONLY for `paused`/`hidden`
  /// (Decision 3): `.inactive` — control centre, notification shade, permission
  /// dialogs, the share sheet, the biometric prompt itself — must never start the
  /// clock, or the lock would fight the user (and the biometric flow).
  ///
  /// First stamp wins: iOS fires `hidden` before `paused`, and taking the earlier
  /// instant is the conservative reading of "when did they leave".
  void noteBackgrounded() {
    _backgroundedAtMs ??= _nowMs;
  }

  /// The foreground return (Decision 3). Two jobs, in order:
  ///
  /// 1. The DEGRADED-BOOT reconcile (Decision 2; review finding SEC-3): if the
  ///    boot read threw, re-read the store ONCE. If an enabled record surfaces,
  ///    lock immediately — the fail-open is a one-launch exposure that self-heals,
  ///    not a process-lifetime hole.
  /// 2. The grace window: re-lock iff the app was PAUSED/HIDDEN and `now -
  ///    backgroundedAt > 60s`, on the app's one clock seam (tests pin it).
  Future<void> noteResumed() async {
    final backgroundedAt = _backgroundedAtMs;
    _backgroundedAtMs = null;

    if (_degradedReconcilePending) {
      _degradedReconcilePending = false;
      final gen = _generation;
      try {
        final record = await _store.read();
        if (gen != _generation) return;
        if (record != null && record.isSet) {
          _record = record;
          state = PrivacyLocked(lockoutUntilMs: record.lockoutUntilMs);
          return;
        }
      } catch (_) {
        // Still degraded. Stay fail-open; the next launch reads again.
      }
    }

    final record = _record;
    if (record == null || !record.isSet) return;
    if (backgroundedAt == null) return;
    if (state is! PrivacyLockUnlocked) return;
    if (_nowMs - backgroundedAt <= kLockGraceWindow.inMilliseconds) return;

    // `biometricAvailable` stays false until the freshly-mounted lock screen
    // calls [refreshBiometricAvailability] — which is also where a stale
    // enrollment gets caught. Offering a button we have not re-validated would be
    // exactly the over-claim Decision 1 forbids.
    state = PrivacyLocked(lockoutUntilMs: record.lockoutUntilMs);
  }

  /// Persists a wrong attempt (the shared half of [verifyPin] and [disableLock]).
  Future<void> _persistWrongAttempt(
    PinLockRecord record,
    int gen,
    int nowMs,
  ) async {
    final wrongCount = record.wrongCount + 1;
    final cooldown = cooldownFor(wrongCount);
    final lockoutUntilMs = cooldown == null
        ? null
        : nowMs + cooldown.inMilliseconds;
    final incremented = record.copyWith(
      wrongCount: wrongCount,
      lockoutUntilMs: lockoutUntilMs,
    );
    if (gen != _generation) return;
    _record = incremented;
    await _writeQuietly(incremented);
  }

  /// Rewrites the record with the accelerator OFF and shows the honest state
  /// (Decision 1's enrollment-change revocation). Never touches an UNLOCKED state
  /// — a revoke discovered while the user is inside settings must not throw the
  /// lock screen over the screen they are standing on; the toggle simply reads
  /// off.
  ///
  /// RE-BASES on the CURRENT `_record`, never on the caller's pre-await capture.
  /// [refreshBiometricAvailability] runs two channel awaits before it decides to
  /// revoke, and it is deliberately NOT `_busy`-guarded (guarding it would drop
  /// the user's first keypress while a mount-time probe is in flight). So a
  /// wrong-PIN persist can land inside that window; revoking from the stale
  /// capture would write back the pre-increment `wrongCount` and silently refund
  /// the attempt — an attempt-bounding bypass reachable by exactly the partner
  /// who triggered the enrollment change (Decision 4's counter is the REAL online
  /// control; it must not be resettable from this path).
  Future<void> _revokeBiometric(int gen) async {
    if (gen != _generation) return;
    final record = _record;
    if (record == null || !record.isSet || !record.biometricEnabled) return;

    final revoked = record.copyWith(
      biometricEnabled: false,
      biometricEnrollmentState: null,
    );
    _record = revoked;
    await _writeQuietly(revoked);
    if (gen != _generation) return;

    if (state is PrivacyLockUnlocked) return;
    state = PrivacyLocked(
      lockoutUntilMs: _record?.lockoutUntilMs,
      biometricRevoked: true,
    );
  }

  /// A store write whose FAILURE must not change the verdict.
  ///
  /// Fail direction (Decision 8's spirit, applied to the paths D8 does not name
  /// explicitly): a failed persist must never hand back a FREE attempt or block
  /// an unlock the user legitimately earned. So the caller proceeds on its
  /// in-memory record — the bound is still enforced for THIS launch — and the
  /// degradation is only that a relaunch may lose the increment. Refusing to
  /// proceed instead would brick the lock screen on a storage fault; re-throwing
  /// would surface a storage error where the honest answer is "wrong PIN".
  /// (The enable path is deliberately NOT routed through here: there, a failed
  /// write MUST report failure — never claim a lock that did not persist.)
  Future<void> _writeQuietly(PinLockRecord record) async {
    try {
      await _store.write(record);
    } catch (_) {
      // Intentionally swallowed — see above.
    }
  }
}
