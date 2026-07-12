import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../observability/crash_reporter.dart';

part 'pin_lock_store.g.dart';

/// The schema version of the persisted lock record (ADR-018 Decision 2). One key,
/// one versioned record: `version` gates any future migration, and an UNKNOWN (or
/// absent) version deserialises to `null` — treated as absent rather than
/// guessed at. Reading a record we do not understand and acting on half of it is
/// how a lock silently becomes a non-lock.
const int kPinLockRecordVersion = 1;

/// The one Keychain record behind the device lock (ADR-018 Decision 2):
/// `{version, salt, pinHash, biometricEnabled, biometricEnrollmentState,
/// wrongCount, lockoutUntilMs}` under a single key, so the bootstrap read is one
/// round-trip and every write is atomic at the Keychain-item level.
///
/// The counter and the cooldown deadline live IN the record on purpose
/// (Decision 4): an in-memory counter would mean "unlimited attempts, 5 per
/// relaunch".
///
/// CRITICAL — the no-content rule (architecture §8, ADR-017 Decision 5's twin).
/// Crashlytics is ON in prod and the global error hooks forward every uncaught
/// error's `toString()`. So [toString] renders field PRESENCE ONLY — never the
/// salt, the hash, the enrollment bytes, and obviously never a PIN digit. The
/// `CoachTranscriptState` COUNT-not-content precedent, applied to secrets. A
/// sentinel test pins it; do not "improve" this renderer.
class PinLockRecord {
  const PinLockRecord({
    required this.salt,
    required this.pinHash,
    required this.biometricEnabled,
    required this.wrongCount,
    this.version = kPinLockRecordVersion,
    this.biometricEnrollmentState,
    this.lockoutUntilMs,
  });

  /// The record schema version — always [kPinLockRecordVersion] for records this
  /// build writes.
  final int version;

  /// The per-device random 128-bit salt, base64. See `pin_hasher.dart` for why
  /// this is a plain salted SHA-256 and deliberately not an iterated KDF.
  final String salt;

  /// base64 of `SHA-256(saltBytes ‖ utf8(pin))`. Empty means "no PIN set".
  final String pinHash;

  /// Whether the biometric accelerator is enabled (Decision 1). It is only ever
  /// an accelerator; the PIN is the credential.
  final bool biometricEnabled;

  /// The opaque platform biometric-enrollment state captured when biometric was
  /// enabled (iOS `evaluatedPolicyDomainState`). A MISMATCH at lock-screen mount
  /// auto-revokes the accelerator (Decision 1 — a partner who adds their face
  /// after enable gains nothing). Null whenever [biometricEnabled] is false.
  final String? biometricEnrollmentState;

  /// Cumulative wrong PIN attempts since the last successful unlock (Decision 4).
  final int wrongCount;

  /// Wall-clock deadline (ms since epoch) before which attempts are refused, or
  /// null when no cooldown is running. Wall time: a device-clock jump forward
  /// elapses it — recorded honestly in Decision 4, not defended against.
  final int? lockoutUntilMs;

  /// Whether a PIN is actually set. A record with an empty hash is not a lock.
  bool get isSet => pinHash.isNotEmpty;

  PinLockRecord copyWith({
    String? salt,
    String? pinHash,
    bool? biometricEnabled,
    Object? biometricEnrollmentState = _unset,
    int? wrongCount,
    Object? lockoutUntilMs = _unset,
  }) => PinLockRecord(
    salt: salt ?? this.salt,
    pinHash: pinHash ?? this.pinHash,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    biometricEnrollmentState: identical(biometricEnrollmentState, _unset)
        ? this.biometricEnrollmentState
        : biometricEnrollmentState as String?,
    wrongCount: wrongCount ?? this.wrongCount,
    lockoutUntilMs: identical(lockoutUntilMs, _unset)
        ? this.lockoutUntilMs
        : lockoutUntilMs as int?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'salt': salt,
    'pinHash': pinHash,
    'biometricEnabled': biometricEnabled,
    'biometricEnrollmentState': biometricEnrollmentState,
    'wrongCount': wrongCount,
    'lockoutUntilMs': lockoutUntilMs,
  };

  /// Total, never-throwing deserialisation. An unknown/absent version, a missing
  /// field, or a wrong-typed field all yield `null` — this runs on the BOOT path
  /// (Decision 2) and a throw there would be a crash before the first frame.
  /// Absent is the honest reading of "we cannot understand this record".
  static PinLockRecord? fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int || version != kPinLockRecordVersion) return null;

    final salt = json['salt'];
    final pinHash = json['pinHash'];
    final biometricEnabled = json['biometricEnabled'];
    final enrollment = json['biometricEnrollmentState'];
    final wrongCount = json['wrongCount'];
    final lockoutUntilMs = json['lockoutUntilMs'];

    if (salt is! String) return null;
    if (pinHash is! String) return null;
    if (biometricEnabled is! bool) return null;
    if (enrollment != null && enrollment is! String) return null;
    if (wrongCount is! int) return null;
    if (lockoutUntilMs != null && lockoutUntilMs is! int) return null;

    return PinLockRecord(
      version: version,
      salt: salt,
      pinHash: pinHash,
      biometricEnabled: biometricEnabled,
      biometricEnrollmentState: enrollment as String?,
      wrongCount: wrongCount,
      lockoutUntilMs: lockoutUntilMs as int?,
    );
  }

  /// The exact string the Keychain holds.
  String encode() => jsonEncode(toJson());

  /// The inverse of [encode]. Lives HERE, not in the plugin-backed adapter, so
  /// the parse that runs on the boot path is unit-tested (review finding TEST-5:
  /// the adapter file stays out of the coverage denominator).
  static PinLockRecord? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinLockRecord &&
          other.version == version &&
          other.salt == salt &&
          other.pinHash == pinHash &&
          other.biometricEnabled == biometricEnabled &&
          other.biometricEnrollmentState == biometricEnrollmentState &&
          other.wrongCount == wrongCount &&
          other.lockoutUntilMs == lockoutUntilMs;

  @override
  int get hashCode => Object.hash(
    version,
    salt,
    pinHash,
    biometricEnabled,
    biometricEnrollmentState,
    wrongCount,
    lockoutUntilMs,
  );

  /// PRESENCE ONLY — see the class doc. Never salt/hash/enrollment/PIN.
  @override
  String toString() =>
      'PinLockRecord(set: $isSet, biometric: $biometricEnabled, '
      'wrongCount: $wrongCount, lockedOut: ${lockoutUntilMs != null})';
}

/// The private "argument not passed" sentinel for [PinLockRecord.copyWith] —
/// lets a caller distinguish "leave it alone" from "set it to null" on the two
/// nullable fields (clearing the lockout and revoking the enrollment state are
/// both real, load-bearing operations).
const Object _unset = Object();

/// The on-device lock-record seam (ADR-018 Decision 2). Interface and record
/// ONLY: the real Keychain adapter lives in `secure_storage_pin_lock_store.dart`
/// (the `LocalFlagStore` file-split precedent) so the device-only,
/// plugin-channel code never enters `flutter test` or the coverage denominator
/// (review finding TEST-5). Tests use the in-memory `FakePinLockStore`.
///
/// Not [LocalFlagStore]: that seam is one-way STICKY by contract (set-once,
/// never cleared) and the lock must be clearable — and prefs are the wrong
/// persistence domain entirely (the reinstall bypass, ADR-018 Context).
abstract interface class PinLockStore {
  /// The stored record, or null when absent / unreadable-as-a-known-version.
  /// THROWS only on a genuine platform read failure — the bootstrap helper
  /// ([readInitialLockSnapshot]) is the one place that catch happens.
  Future<PinLockRecord?> read();

  /// Persists [record], replacing whatever is there. Atomic at the item level.
  Future<void> write(PinLockRecord record);

  /// Removes the record entirely (the sign-out wipe, and disable-lock).
  Future<void> clear();
}

/// Provides the app's [PinLockStore].
///
/// Deliberately unimplemented at the base (the repository-seam discipline
/// everywhere else): the flavor entrypoints override it BY VALUE with a
/// `SecureStoragePinLockStore`, and tests override it with a `FakePinLockStore`.
@Riverpod(keepAlive: true)
PinLockStore pinLockStore(Ref ref) => throw StateError(
  'pinLockStoreProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);

/// The bootstrap read's outcome (ADR-018 Decision 2). The gate must decide the
/// FIRST frame — a flash of couple content before an async lock check is a real
/// leak, and the app-switcher snapshot of that flash doubly so — so the
/// entrypoints await ONE read before `runHayati` and override
/// [initialLockSnapshotProvider] by value.
///
/// [degraded] is the load-bearing distinction (review finding SEC-3): a CLEAN
/// null (no record) is final; a null because the read THREW is a one-launch
/// fail-open that the controller self-heals by re-reading once on the first
/// `resumed`. Fail-closed at boot would brick the app behind a lock screen that
/// can verify nothing — and reinstalling does not even clear the Keychain, so
/// the brick would be permanent.
class PinLockSnapshot {
  const PinLockSnapshot({required this.record, this.degraded = false});

  /// The record read at boot, or null (absent, unknown-version, or degraded).
  final PinLockRecord? record;

  /// True iff the boot read THREW. Never true alongside a non-null [record].
  final bool degraded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinLockSnapshot &&
          other.record == record &&
          other.degraded == degraded;

  @override
  int get hashCode => Object.hash(record, degraded);

  /// Presence only — [PinLockRecord.toString] already carries the no-content
  /// rule, and this must not undo it.
  @override
  String toString() => 'PinLockSnapshot(record: $record, degraded: $degraded)';
}

/// The boot snapshot, overridden BY VALUE at bootstrap (and per test container).
/// Never read after `build()` seeds the controller: it is a boot-time constant,
/// and re-running the controller's `build()` against it would replay boot state
/// (which is exactly why nothing may `ref.invalidate` the lock controller —
/// ADR-018 Decision 1, review finding FLUTTER-2).
@Riverpod(keepAlive: true)
PinLockSnapshot initialLockSnapshot(Ref ref) => throw StateError(
  'initialLockSnapshotProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);

/// The one place a lock-store read failure is caught (ADR-018 Decision 2's
/// fail-open row). Takes the SEAM, not the adapter, so it is unit-tested and
/// the plugin never enters the test binary. Called by the entrypoints before
/// `runHayati`.
///
/// "Fail OPEN, **loudly**" is the ADR's phrasing, and [reporter] is the loud
/// half — without it, the ONE state in which the lock is silently not protecting
/// a user who believes it is would leave no trace anywhere (Decision 8's first
/// row; post-implementation review finding SPEC-2). The entrypoints pass the
/// Crashlytics-backed reporter; widget tests pass none.
///
/// The breadcrumb carries a fixed marker and the error's **runtimeType only** —
/// never its `toString()`, which on a Keychain fault could carry the item's key
/// or attributes. The no-content rule (architecture §8) governs diagnostics too.
Future<PinLockSnapshot> readInitialLockSnapshot(
  PinLockStore store, {
  CrashReporter? reporter,
}) async {
  try {
    return PinLockSnapshot(record: await store.read());
  } catch (error) {
    // Fail OPEN: degraded → disabled first frame + a one-shot re-read on the
    // first resume (the controller's reconcile). An attacker cannot induce a
    // Keychain read failure without device-level compromise (out of threat
    // model), and a permanent brick is the worse failure — reinstalling does not
    // clear the Keychain. But it must never be SILENT.
    await reporter?.log(
      'privacy_lock: boot read failed (${error.runtimeType}); failing open, '
      'degraded snapshot, will re-read on first resume',
    );
    return const PinLockSnapshot(record: null, degraded: true);
  }
}
