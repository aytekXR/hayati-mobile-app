import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/privacy_lock/domain/pin_hasher.dart';
import 'package:hayati_app/features/privacy_lock/domain/pin_lock_attempt_result.dart';
import 'package:hayati_app/features/privacy_lock/domain/pin_lock_cooldown.dart';
import 'package:hayati_app/features/privacy_lock/presentation/state/privacy_lock_controller.dart';

import '../../../../support/fake_biometric_authenticator.dart';
import '../../../../support/fake_pin_lock_store.dart';

void main() {
  const correctPin = '123456';
  const wrongPin = '000000';
  const reason = 'Unlock Hayati';

  /// A fixed, recognisable salt — so the no-content sentinel below can search a
  /// `toString()` haystack for material it KNOWS is in the record.
  final salt = base64Encode(List<int>.filled(16, 7));
  final correctHash = hashPin(pin: correctPin, salt: salt);

  final start = DateTime.utc(2026, 7, 12, 9);
  late DateTime now;

  setUp(() => now = start);

  PinLockRecord aRecord({
    int wrongCount = 0,
    int? lockoutUntilMs,
    bool biometricEnabled = false,
    String? enrollment,
  }) => PinLockRecord(
    salt: salt,
    pinHash: correctHash,
    biometricEnabled: biometricEnabled,
    biometricEnrollmentState: enrollment,
    wrongCount: wrongCount,
    lockoutUntilMs: lockoutUntilMs,
  );

  /// Boots a container the way the entrypoints do: the store seam plus the
  /// BY-VALUE boot snapshot (ADR-018 Decision 2), with the clock pinned.
  ProviderContainer boot({
    required FakePinLockStore store,
    PinLockSnapshot? snapshot,
    FakeBiometricAuthenticator? biometric,
  }) {
    final container = ProviderContainer(
      overrides: [
        pinLockStoreProvider.overrideWithValue(store),
        initialLockSnapshotProvider.overrideWithValue(
          snapshot ?? PinLockSnapshot(record: store.record),
        ),
        biometricAuthenticatorProvider.overrideWithValue(
          biometric ?? FakeBiometricAuthenticator(),
        ),
        soloClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  PrivacyLockState stateOf(ProviderContainer c) =>
      c.read(privacyLockControllerProvider);

  PrivacyLockController controllerOf(ProviderContainer c) =>
      c.read(privacyLockControllerProvider.notifier);

  int msFromStart(Duration d) => start.add(d).millisecondsSinceEpoch;

  group('boot (the synchronous first-frame seed — ADR-018 Decision 2/3)', () {
    test('an enabled record locks — a cold start ALWAYS locks', () {
      final store = FakePinLockStore(initial: aRecord());
      expect(stateOf(boot(store: store)), const PrivacyLocked());
    });

    test('a cold start replays a live cooldown deadline', () {
      final until = msFromStart(const Duration(seconds: 30));
      final store = FakePinLockStore(
        initial: aRecord(wrongCount: 5, lockoutUntilMs: until),
      );
      expect(
        stateOf(boot(store: store)),
        PrivacyLocked(lockoutUntilMs: until),
        reason: 'killing the app is not a cooldown reset (Decision 4)',
      );
    });

    test('no record → disabled, and the boot read is NOT repeated', () {
      final store = FakePinLockStore();
      expect(stateOf(boot(store: store)), const PrivacyLockDisabled());
      expect(
        store.callLog,
        isEmpty,
        reason: 'build() seeds from the by-value snapshot, synchronously',
      );
    });
  });

  group('verifyPin (Decision 4)', () {
    test('a correct PIN unlocks and persists the counter reset', () async {
      final store = FakePinLockStore(initial: aRecord(wrongCount: 3));
      final container = boot(store: store);

      final result = await controllerOf(container).verifyPin(correctPin);

      expect(result, const PinLockAttemptAccepted());
      expect(stateOf(container), const PrivacyLockUnlocked());
      expect(store.record!.wrongCount, 0);
      expect(store.record!.lockoutUntilMs, isNull);
      expect(store.callLog, ['write:set']);
    });

    test(
      'attempts 1-4 are free; the 5th starts a 30s cooldown (persisted)',
      () async {
        final store = FakePinLockStore(initial: aRecord());
        final container = boot(store: store);
        final controller = controllerOf(container);

        for (var attempt = 1; attempt <= 4; attempt++) {
          final result = await controller.verifyPin(wrongPin);
          expect(
            result,
            PinLockAttemptWrong(
              remainingBeforeCooldown: 4 - attempt,
              tier: null,
            ),
            reason: 'attempt $attempt must be free',
          );
          expect(store.record!.wrongCount, attempt);
          expect(store.record!.lockoutUntilMs, isNull);
          expect(stateOf(container), const PrivacyLocked());
        }

        final fifth = await controller.verifyPin(wrongPin);
        final until = msFromStart(const Duration(seconds: 30));

        expect(
          fifth,
          PinLockAttemptWrong(
            remainingBeforeCooldown: 0,
            cooldownUntilMs: until,
            tier: PinLockCooldownTier.thirtySeconds,
          ),
        );
        expect(store.record!.wrongCount, 5);
        expect(store.record!.lockoutUntilMs, until);
        expect(stateOf(container), PrivacyLocked(lockoutUntilMs: until));
      },
    );

    test(
      'the increment is PERSISTED before the verdict is returned (SEC-4B)',
      () async {
        final store = FakePinLockStore(initial: aRecord());
        final container = boot(store: store);
        final gate = Completer<void>();
        store.writeGate = gate;

        var settled = false;
        final verdict = controllerOf(
          container,
        ).verifyPin(wrongPin).whenComplete(() => settled = true);

        await pumpEventQueue();
        expect(
          settled,
          isFalse,
          reason:
              'the verdict must not render while the write is in flight — a '
              'kill in that window would land on the FREE side',
        );
        expect(store.record!.wrongCount, 0, reason: 'the write is parked');

        gate.complete();
        expect(await verdict, isA<PinLockAttemptWrong>());
        expect(settled, isTrue);
        expect(store.record!.wrongCount, 1);
      },
    );

    test('a running cooldown REFUSES without consuming an attempt', () async {
      final until = msFromStart(const Duration(seconds: 30));
      final store = FakePinLockStore(
        initial: aRecord(wrongCount: 5, lockoutUntilMs: until),
      );
      final container = boot(store: store);

      final refused = await controllerOf(container).verifyPin(wrongPin);

      expect(
        refused,
        PinLockAttemptCooldown(
          cooldownUntilMs: until,
          tier: PinLockCooldownTier.thirtySeconds,
        ),
      );
      expect(store.record!.wrongCount, 5, reason: 'not consumed');
      expect(store.callLog, isEmpty, reason: 'nothing written, nothing read');
    });

    test(
      'an expired cooldown re-allows attempts; the 6th tier is a minute',
      () async {
        final until = msFromStart(const Duration(seconds: 30));
        final store = FakePinLockStore(
          initial: aRecord(wrongCount: 5, lockoutUntilMs: until),
        );
        final container = boot(store: store);

        now = start.add(const Duration(seconds: 31));
        final sixth = await controllerOf(container).verifyPin(wrongPin);

        expect(
          sixth,
          PinLockAttemptWrong(
            remainingBeforeCooldown: 0,
            cooldownUntilMs: now
                .add(const Duration(minutes: 1))
                .millisecondsSinceEpoch,
            tier: PinLockCooldownTier.oneMinute,
          ),
        );
        expect(store.record!.wrongCount, 6);
      },
    );

    test(
      'a correct PIN during a cooldown is still refused (not consumed)',
      () async {
        final until = msFromStart(const Duration(seconds: 30));
        final store = FakePinLockStore(
          initial: aRecord(wrongCount: 5, lockoutUntilMs: until),
        );
        final container = boot(store: store);

        expect(
          await controllerOf(container).verifyPin(correctPin),
          isA<PinLockAttemptCooldown>(),
        );
        expect(stateOf(container), isA<PrivacyLocked>());
      },
    );

    test(
      'the counter and the cooldown SURVIVE a relaunch (Decision 4)',
      () async {
        final store = FakePinLockStore(initial: aRecord());
        final first = boot(store: store);
        for (var i = 0; i < 5; i++) {
          await controllerOf(first).verifyPin(wrongPin);
        }
        expect(store.record!.wrongCount, 5);

        // "Relaunch": a fresh container over the SAME device store, seeded from a
        // fresh bootstrap read of it.
        final relaunched = boot(store: store);

        expect(
          stateOf(relaunched),
          PrivacyLocked(
            lockoutUntilMs: msFromStart(const Duration(seconds: 30)),
          ),
        );
        expect(
          await controllerOf(relaunched).verifyPin(wrongPin),
          isA<PinLockAttemptCooldown>(),
          reason: 'a restart is not a retry reset',
        );
        expect(store.record!.wrongCount, 5);
      },
    );
  });

  group('wipe — the sign-out path (Decision 1)', () {
    test('clears the store and mutates the state IN PLACE', () async {
      final store = FakePinLockStore(initial: aRecord(wrongCount: 2));
      final container = boot(store: store);
      expect(stateOf(container), isA<PrivacyLocked>());

      await controllerOf(container).wipe();

      expect(stateOf(container), const PrivacyLockDisabled());
      expect(store.record, isNull);
      expect(store.callLog, ['clear']);
    });

    test('the wiped state SURVIVES a re-read — no invalidate, no boot replay '
        '(FLUTTER-2 regression pin)', () async {
      final store = FakePinLockStore(initial: aRecord());
      final container = boot(store: store);
      await controllerOf(container).wipe();

      // If any future code path swapped the in-place mutation for
      // `ref.invalidate(privacyLockControllerProvider)`, build() would re-run
      // against the STALE by-value boot snapshot and resurrect the LOCKED
      // state — re-locking a signed-out app with the previous user's PIN.
      expect(stateOf(container), const PrivacyLockDisabled());
      expect(
        container.read(privacyLockControllerProvider),
        const PrivacyLockDisabled(),
      );
    });

    test(
      'a failing clear still drops the lock state (orphaned ≠ bricked)',
      () async {
        final store = FakePinLockStore(initial: aRecord())
          ..onClear = () async => throw StateError('keychain fault');
        final container = boot(store: store);

        await controllerOf(container).wipe();

        expect(stateOf(container), const PrivacyLockDisabled());
      },
    );
  });

  group('THE GENERATION-GUARD RACE (the S019 class — FLUTTER-3, blocking)', () {
    test('a wrong-attempt persist in flight when the wipe fires does not '
        'resurrect the pinHash, and does not re-lock', () async {
      final store = FakePinLockStore(initial: aRecord());
      final container = boot(store: store);
      final controller = controllerOf(container);

      final gate = Completer<void>();
      store.writeGate = gate;

      final attempt = controller.verifyPin(wrongPin);
      await pumpEventQueue();
      expect(store.callLog, ['write:set'], reason: 'the write is parked');

      // Sign-out lands mid-attempt. `ref.mounted` cannot catch this: the
      // keepAlive controller is wiped IN PLACE and stays mounted.
      final wiped = controller.wipe();
      expect(
        stateOf(container),
        const PrivacyLockDisabled(),
        reason: 'the wipe flips the state synchronously',
      );

      gate.complete();
      expect(
        await attempt,
        const PinLockAttemptAborted(),
        reason: 'the in-flight op aborted on the generation bump',
      );
      await wiped;

      expect(
        store.record,
        isNull,
        reason: 'no pinHash resurrection — the next user inherits nothing',
      );
      expect(
        stateOf(container),
        const PrivacyLockDisabled(),
        reason: 'the aborted attempt assigned no state',
      );
      expect(store.callLog.last, 'clear', reason: 'no write after the clear');
    });

    test(
      'a post-biometric write racing the wipe is ABORTED (the write issued '
      'AFTER an await — the guard is the only thing that can stop it)',
      () async {
        final store = FakePinLockStore(
          initial: aRecord(
            wrongCount: 3,
            biometricEnabled: true,
            enrollment: 'e1',
          ),
        );
        final biometric = FakeBiometricAuthenticator(enrollment: 'e1')
          ..authenticateGate = Completer<void>();
        final container = boot(store: store, biometric: biometric);
        final controller = controllerOf(container);

        final auth = controller.authenticateBiometric(reason: reason);
        await pumpEventQueue();

        final wiped = controller.wipe();
        biometric.authenticateGate!.complete();

        expect(await auth, isFalse);
        await wiped;

        expect(store.record, isNull, reason: 'the reset write never landed');
        expect(stateOf(container), const PrivacyLockDisabled());
        expect(
          store.callLog.where((c) => c.startsWith('write')),
          isEmpty,
          reason: 'the guard aborted before the store write',
        );
      },
    );
  });

  group('the grace window (Decision 3)', () {
    Future<ProviderContainer> unlocked(FakePinLockStore store) async {
      final container = boot(store: store);
      await controllerOf(container).verifyPin(correctPin);
      expect(stateOf(container), const PrivacyLockUnlocked());
      return container;
    }

    test('a return within 59s stays unlocked', () async {
      final container = await unlocked(FakePinLockStore(initial: aRecord()));

      controllerOf(container).noteBackgrounded();
      now = start.add(const Duration(seconds: 59));
      await controllerOf(container).noteResumed();

      expect(stateOf(container), const PrivacyLockUnlocked());
    });

    test('exactly 60s is still within grace (the boundary is >)', () async {
      final container = await unlocked(FakePinLockStore(initial: aRecord()));

      controllerOf(container).noteBackgrounded();
      now = start.add(kLockGraceWindow);
      await controllerOf(container).noteResumed();

      expect(stateOf(container), const PrivacyLockUnlocked());
    });

    test('a return at 61s re-locks', () async {
      final container = await unlocked(FakePinLockStore(initial: aRecord()));

      controllerOf(container).noteBackgrounded();
      now = start.add(const Duration(seconds: 61));
      await controllerOf(container).noteResumed();

      expect(stateOf(container), const PrivacyLocked());
    });

    test('without a backgrounded stamp, a resume NEVER locks — `.inactive` (the '
        'share sheet, the biometric prompt, permission dialogs) must not fight '
        'the user', () async {
      final container = await unlocked(FakePinLockStore(initial: aRecord()));

      // noteBackgrounded deliberately NOT called: this is the `.inactive` path.
      now = start.add(const Duration(hours: 2));
      await controllerOf(container).noteResumed();

      expect(stateOf(container), const PrivacyLockUnlocked());
    });

    test('the FIRST stamp wins (iOS fires hidden before paused)', () async {
      final container = await unlocked(FakePinLockStore(initial: aRecord()));
      final controller = controllerOf(container);

      controller.noteBackgrounded(); // hidden
      now = start.add(const Duration(seconds: 40));
      controller.noteBackgrounded(); // paused — must not restart the clock
      now = start.add(const Duration(seconds: 61));
      await controller.noteResumed();

      expect(stateOf(container), const PrivacyLocked());
    });

    test(
      'a grace re-lock does NOT offer the biometric button until the freshly '
      'mounted lock screen re-validates the enrollment (D1)',
      () async {
        final store = FakePinLockStore(
          initial: aRecord(biometricEnabled: true, enrollment: 'e1'),
        );
        final container = await unlocked(store);

        controllerOf(container).noteBackgrounded();
        now = start.add(const Duration(seconds: 61));
        await controllerOf(container).noteResumed();

        expect(
          stateOf(container),
          const PrivacyLocked(),
          reason:
              'biometricAvailable stays false until refresh re-checks — '
              'offering an unvalidated accelerator is exactly the over-claim '
              'Decision 1 forbids',
        );
      },
    );

    test('the grace window is 60 seconds (the constant the widget shares)', () {
      expect(kLockGraceWindow, const Duration(seconds: 60));
    });
  });

  group('the degraded-boot reconcile (Decision 2 — SEC-3)', () {
    test(
      'a boot read that THREW starts open, then the FIRST resume re-reads and '
      'locks',
      () async {
        final store = FakePinLockStore(initial: aRecord(wrongCount: 2));
        final container = boot(
          store: store,
          snapshot: const PinLockSnapshot(record: null, degraded: true),
        );

        expect(
          stateOf(container),
          const PrivacyLockDisabled(),
          reason: 'fail OPEN for one launch — a brick would be permanent',
        );

        await controllerOf(container).noteResumed();

        expect(stateOf(container), const PrivacyLocked());
        expect(store.callLog, ['read']);
      },
    );

    test('the re-read happens ONCE, not on every resume', () async {
      final store = FakePinLockStore();
      final container = boot(
        store: store,
        snapshot: const PinLockSnapshot(record: null, degraded: true),
      );

      await controllerOf(container).noteResumed();
      await controllerOf(container).noteResumed();

      expect(store.callLog, ['read']);
      expect(stateOf(container), const PrivacyLockDisabled());
    });

    test(
      'a CLEAN absent boot never re-reads (a clean null is final)',
      () async {
        final store = FakePinLockStore(initial: aRecord());
        final container = boot(
          store: store,
          snapshot: const PinLockSnapshot(record: null),
        );

        await controllerOf(container).noteResumed();

        expect(store.callLog, isEmpty);
        expect(stateOf(container), const PrivacyLockDisabled());
      },
    );

    test('a still-throwing re-read stays open rather than bricking', () async {
      final store = FakePinLockStore(initial: aRecord())
        ..onRead = () async => throw StateError('keychain fault');
      final container = boot(
        store: store,
        snapshot: const PinLockSnapshot(record: null, degraded: true),
      );

      await controllerOf(container).noteResumed();

      expect(stateOf(container), const PrivacyLockDisabled());
    });
  });

  group('biometric (Decision 1)', () {
    test('an enrollment MATCH authenticates and unlocks', () async {
      final store = FakePinLockStore(
        initial: aRecord(
          wrongCount: 2,
          biometricEnabled: true,
          enrollment: 'e1',
        ),
      );
      final biometric = FakeBiometricAuthenticator(enrollment: 'e1');
      final container = boot(store: store, biometric: biometric);

      final ok = await controllerOf(
        container,
      ).authenticateBiometric(reason: reason);

      expect(ok, isTrue);
      expect(stateOf(container), const PrivacyLockUnlocked());
      expect(store.record!.wrongCount, 0, reason: 'success resets the counter');
      expect(biometric.callLog, ['enrollmentState', 'authenticate:$reason']);
    });

    test(
      'an enrollment MISMATCH AUTO-REVOKES the accelerator and demands the PIN '
      '— the prompt is never even shown (DVUX-1)',
      () async {
        final store = FakePinLockStore(
          initial: aRecord(biometricEnabled: true, enrollment: 'e1'),
        );
        // The partner added their face AFTER the user enabled biometric.
        final biometric = FakeBiometricAuthenticator(enrollment: 'e2');
        final container = boot(store: store, biometric: biometric);

        final ok = await controllerOf(
          container,
        ).authenticateBiometric(reason: reason);

        expect(ok, isFalse);
        expect(biometric.authenticateCalled, isFalse);
        expect(store.record!.biometricEnabled, isFalse);
        expect(store.record!.biometricEnrollmentState, isNull);
        expect(stateOf(container), const PrivacyLocked(biometricRevoked: true));
      },
    );

    test('refresh at lock-screen mount auto-revokes on a mismatch', () async {
      final store = FakePinLockStore(
        initial: aRecord(biometricEnabled: true, enrollment: 'e1'),
      );
      final biometric = FakeBiometricAuthenticator(enrollment: 'e2');
      final container = boot(store: store, biometric: biometric);

      await controllerOf(container).refreshBiometricAvailability();

      expect(store.record!.biometricEnabled, isFalse);
      expect(stateOf(container), const PrivacyLocked(biometricRevoked: true));
    });

    test('a revoke racing a wrong-PIN persist must NOT refund the consumed attempt '
        '— the counter-refund race', () async {
      // The exact shape a partner can drive: change the biometric enrollment
      // (so the next lock-screen mount will REVOKE), then guess a PIN while
      // the mount-time probes are still in flight. `refreshBiometricAvailability`
      // is deliberately not `_busy`-guarded, so the wrong-PIN persist lands
      // INSIDE the probe window. If the revoke wrote back the record it captured
      // BEFORE the probes, `wrongCount` would roll back to 0 — an unbounded PIN
      // oracle, resettable at will. The revoke must re-base on the CURRENT record.
      final store = FakePinLockStore(
        initial: aRecord(
          wrongCount: 3,
          biometricEnabled: true,
          enrollment: 'e1',
        ),
      );
      final biometric = FakeBiometricAuthenticator(enrollment: 'e2')
        ..probeGate = Completer<void>();
      final container = boot(store: store, biometric: biometric);
      final controller = controllerOf(container);

      // The mount-time refresh parks on its first probe.
      final refresh = controller.refreshBiometricAvailability();
      await pumpEventQueue();

      // The 4th wrong attempt lands and is persisted while the probe is parked.
      final attempt = await controller.verifyPin(wrongPin);
      expect(attempt, isA<PinLockAttemptWrong>());
      expect(store.record!.wrongCount, 4);

      // Now let the revoke complete.
      biometric.probeGate!.complete();
      await refresh;

      expect(
        store.record!.biometricEnabled,
        isFalse,
        reason: 'the revoke still happened',
      );
      expect(
        store.record!.wrongCount,
        4,
        reason: 'the consumed attempt survives the revoke — never refunded',
      );

      // And the bound still bites: the 5th wrong attempt starts the cooldown.
      final fifth = await controller.verifyPin(wrongPin);
      expect(fifth, isA<PinLockAttemptWrong>());
      expect(store.record!.lockoutUntilMs, isNotNull);
    });

    test('the same refund race, one beat EARLIER: the revoke re-bases while the '
        "wrong-attempt's write is still in flight", () async {
      // The tighter interleaving the previous test cannot reach: the probes
      // resolve while `verifyPin`'s store write is STILL PARKED. This is why the
      // controller advances `_record` BEFORE awaiting that write — a re-baser
      // landing inside the write window must already see the consumed attempt.
      // Advancing `_record` only after the write would leave a stale record
      // visible for the whole width of a Keychain round-trip.
      final store = FakePinLockStore(
        initial: aRecord(
          wrongCount: 3,
          biometricEnabled: true,
          enrollment: 'e1',
        ),
      )..writeGate = Completer<void>();
      final biometric = FakeBiometricAuthenticator(enrollment: 'e2');
      final container = boot(store: store, biometric: biometric);
      final controller = controllerOf(container);

      // The attempt parks on its (gated) persist — `_record` is already advanced.
      final attempt = controller.verifyPin(wrongPin);
      await pumpEventQueue();

      // The mount-time refresh runs its probes to completion INSIDE that window
      // and decides to revoke.
      final refresh = controller.refreshBiometricAvailability();
      await pumpEventQueue();

      store.writeGate!.complete();
      expect(await attempt, isA<PinLockAttemptWrong>());
      await refresh;

      expect(store.record!.biometricEnabled, isFalse);
      expect(
        store.record!.wrongCount,
        4,
        reason:
            'the in-flight attempt is not refunded by the revoke that '
            're-based mid-write',
      );
    });

    test('refresh auto-revokes when biometrics went UNAVAILABLE', () async {
      final store = FakePinLockStore(
        initial: aRecord(biometricEnabled: true, enrollment: 'e1'),
      );
      final biometric = FakeBiometricAuthenticator(
        available: false,
        enrollment: 'e1',
      );
      final container = boot(store: store, biometric: biometric);

      await controllerOf(container).refreshBiometricAvailability();

      expect(store.record!.biometricEnabled, isFalse);
      expect(stateOf(container), const PrivacyLocked(biometricRevoked: true));
    });

    test('refresh on a MATCH offers the button and writes nothing', () async {
      final store = FakePinLockStore(
        initial: aRecord(biometricEnabled: true, enrollment: 'e1'),
      );
      final container = boot(
        store: store,
        biometric: FakeBiometricAuthenticator(enrollment: 'e1'),
      );

      await controllerOf(container).refreshBiometricAvailability();

      expect(stateOf(container), const PrivacyLocked(biometricAvailable: true));
      expect(store.callLog, isEmpty);
    });

    test(
      'refresh leaves the button OFF when biometric is not enabled',
      () async {
        final store = FakePinLockStore(initial: aRecord());
        final container = boot(store: store);

        await controllerOf(container).refreshBiometricAvailability();

        expect(stateOf(container), const PrivacyLocked());
      },
    );

    test('a biometric FAILURE stays locked and consumes NO PIN attempt (the '
        'adapter maps every LocalAuthException to false)', () async {
      final store = FakePinLockStore(
        initial: aRecord(
          wrongCount: 2,
          biometricEnabled: true,
          enrollment: 'e1',
        ),
      );
      final container = boot(
        store: store,
        biometric: FakeBiometricAuthenticator(
          enrollment: 'e1',
          succeeds: false,
        ),
      );

      final ok = await controllerOf(
        container,
      ).authenticateBiometric(reason: reason);

      expect(ok, isFalse);
      expect(stateOf(container), isA<PrivacyLocked>());
      expect(store.record!.wrongCount, 2, reason: 'not a PIN attempt');
      expect(store.record!.lockoutUntilMs, isNull);
      expect(store.callLog, isEmpty);
    });

    test('biometric is refused outright when the record has it off', () async {
      final store = FakePinLockStore(initial: aRecord());
      final biometric = FakeBiometricAuthenticator();
      final container = boot(store: store, biometric: biometric);

      expect(
        await controllerOf(container).authenticateBiometric(reason: reason),
        isFalse,
      );
      expect(biometric.callLog, isEmpty);
    });
  });

  group('settings ops (Decisions 1/7)', () {
    test(
      'enableLock writes the record and leaves THIS session unlocked',
      () async {
        final store = FakePinLockStore();
        final container = boot(store: store);

        final ok = await controllerOf(container).enableLock(correctPin);

        expect(ok, isTrue);
        expect(
          stateOf(container),
          const PrivacyLockUnlocked(),
          reason:
              'the user is standing INSIDE settings — do not lock them out of '
              'the screen they are on; the lock engages next cold start',
        );
        final written = store.record!;
        expect(written.isSet, isTrue);
        expect(written.biometricEnabled, isFalse);
        expect(written.wrongCount, 0);
        expect(
          constantTimeEquals(
            hashPin(pin: correctPin, salt: written.salt),
            written.pinHash,
          ),
          isTrue,
        );
        expect(written.salt, isNot(salt), reason: 'a fresh salt per enable');
      },
    );

    test(
      'a FAILED enable write reports false and claims no protection (D8)',
      () async {
        final store = FakePinLockStore()
          ..onWrite = (_) async => throw StateError('keychain fault');
        final container = boot(store: store);

        expect(await controllerOf(container).enableLock(correctPin), isFalse);
        expect(stateOf(container), const PrivacyLockDisabled());
        expect(store.record, isNull);
      },
    );

    test('disableLock during a COOLDOWN reports the cooldown, NOT a wrong PIN — '
        'the PIN was never compared (DVUX-4)', () async {
      // Settings used to collapse both refusals to `false` and then assert
      // "That PIN didn't match" — telling the owner they mistyped when the app
      // had not even looked at what they typed, on the one surface where they
      // are trying to prove they ARE the owner.
      final until = msFromStart(const Duration(seconds: 30));
      final store = FakePinLockStore(
        initial: aRecord(wrongCount: 5, lockoutUntilMs: until),
      );
      final container = boot(store: store);

      final result = await controllerOf(container).disableLock(correctPin);

      expect(result, isA<PinLockAttemptCooldown>());
      expect(store.record!.wrongCount, 5, reason: 'not consumed');
      expect(store.record, isNotNull, reason: 'the lock stays on');
    });

    test('disableLock with the correct PIN clears the record', () async {
      final store = FakePinLockStore(initial: aRecord());
      final container = boot(store: store);
      await controllerOf(container).verifyPin(correctPin);

      expect(
        await controllerOf(container).disableLock(correctPin),
        const PinLockAttemptAccepted(),
      );
      expect(store.record, isNull);
      expect(stateOf(container), const PrivacyLockDisabled());
    });

    test('disableLock with a WRONG PIN fails and persists the attempt', () async {
      final store = FakePinLockStore(initial: aRecord(wrongCount: 1));
      final container = boot(store: store);
      await controllerOf(container).verifyPin(correctPin);

      // The result TYPE is load-bearing (review finding DVUX-4): settings must be
      // able to say "that PIN was wrong" only when a PIN was actually compared.
      expect(
        await controllerOf(container).disableLock(wrongPin),
        isA<PinLockAttemptWrong>(),
      );
      expect(
        store.record!.wrongCount,
        1,
        reason:
            'the successful verify reset it to 0, so this wrong disable '
            'attempt puts it back at 1 — the same bounding as the lock screen',
      );
      expect(store.record!.isSet, isTrue);
    });

    test(
      'setBiometricEnabled(true) captures the enrollment state — with the PIN',
      () async {
        final store = FakePinLockStore(initial: aRecord());
        final container = boot(
          store: store,
          biometric: FakeBiometricAuthenticator(enrollment: 'e9'),
        );

        expect(
          await controllerOf(
            container,
          ).setBiometricEnabled(true, pin: correctPin),
          isTrue,
        );
        expect(store.record!.biometricEnabled, isTrue);
        expect(store.record!.biometricEnrollmentState, 'e9');
      },
    );

    test('ATTACHING a biometric REQUIRES the PIN — without it, a partner holding a '
        'momentarily-unlocked phone gains a permanent second credential '
        '(LOCKBYPASS-2)', () async {
      // The attack: the lock is ON, biometric OFF, and the partner catches the
      // phone unlocked (inside the 60s grace, or simply handed it). They walk
      // into Settings and flip Face ID on. The record would capture the CURRENT
      // enrollment state — which already contains THEIR face — giving them a
      // permanent key to the lock, silently, with zero PIN knowledge. The
      // enrollment-change revocation cannot save us: the enrollment never
      // changed *after* enable; they were captured *inside* it.
      //
      // Attaching a second credential is at least as security-significant as
      // REMOVING the lock — and removing it already demands the PIN.
      final store = FakePinLockStore(initial: aRecord());
      final biometric = FakeBiometricAuthenticator(enrollment: 'partner-face');
      final container = boot(store: store, biometric: biometric);
      final controller = controllerOf(container);

      expect(
        await controller.setBiometricEnabled(true),
        isFalse,
        reason: 'no PIN, no accelerator',
      );
      expect(
        await controller.setBiometricEnabled(true, pin: wrongPin),
        isFalse,
      );

      expect(store.record!.biometricEnabled, isFalse);
      expect(store.record!.biometricEnrollmentState, isNull);
      expect(
        biometric.callLog,
        isNot(contains('enrollmentState')),
        reason: 'a wrong PIN must not even reach the enrollment probe',
      );
      // And the wrong attempt is BOUNDED like every other PIN entry, or
      // "enable biometric" would be an unbounded PIN oracle behind the gate.
      expect(store.record!.wrongCount, 1);
    });

    test(
      'DISABLING the accelerator needs no PIN — it only reduces access',
      () async {
        final store = FakePinLockStore(
          initial: aRecord(biometricEnabled: true, enrollment: 'e1'),
        );
        final container = boot(store: store);

        expect(
          await controllerOf(container).setBiometricEnabled(false),
          isTrue,
        );
        expect(store.record!.biometricEnabled, isFalse);
        expect(store.record!.biometricEnrollmentState, isNull);
      },
    );

    test(
      'setBiometricEnabled(true) refuses when the platform has no enrollment '
      'state to capture — never claim an accelerator we cannot validate',
      () async {
        final store = FakePinLockStore(initial: aRecord());
        final container = boot(
          store: store,
          biometric: FakeBiometricAuthenticator(enrollment: null),
        );

        expect(
          await controllerOf(
            container,
          ).setBiometricEnabled(true, pin: correctPin),
          isFalse,
        );
        expect(store.record!.biometricEnabled, isFalse);
      },
    );

    test(
      'setBiometricEnabled(false) nulls the stored enrollment state',
      () async {
        final store = FakePinLockStore(
          initial: aRecord(biometricEnabled: true, enrollment: 'e1'),
        );
        final container = boot(store: store);

        expect(
          await controllerOf(container).setBiometricEnabled(false),
          isTrue,
        );
        expect(store.record!.biometricEnabled, isFalse);
        expect(store.record!.biometricEnrollmentState, isNull);
      },
    );

    test('a FAILED biometric-toggle write reports false', () async {
      final store = FakePinLockStore(initial: aRecord())
        ..onWrite = (_) async => throw StateError('keychain fault');
      final container = boot(
        store: store,
        biometric: FakeBiometricAuthenticator(enrollment: 'e9'),
      );

      expect(await controllerOf(container).setBiometricEnabled(true), isFalse);
      expect(store.record!.biometricEnabled, isFalse);
    });
  });

  group('the no-content rule (architecture §8 — the sentinel)', () {
    test('no lock state toString carries a salt, hash, or enrollment byte', () {
      final store = FakePinLockStore(
        initial: aRecord(
          wrongCount: 5,
          lockoutUntilMs: msFromStart(const Duration(seconds: 30)),
          biometricEnabled: true,
          enrollment: 'ENROLLMENT-BYTES',
        ),
      );
      final container = boot(store: store);

      final rendered = <String>[
        stateOf(container).toString(),
        const PrivacyLockDisabled().toString(),
        const PrivacyLockUnlocked().toString(),
        const PrivacyLocked(
          biometricRevoked: true,
          biometricAvailable: true,
        ).toString(),
      ].join('\n');

      for (final secret in [salt, correctHash, 'ENROLLMENT-BYTES']) {
        expect(rendered, isNot(contains(secret)));
        expect(rendered, isNot(contains(secret.substring(0, 8))));
      }
    });

    test('no attempt result toString carries a PIN or a hash', () async {
      final store = FakePinLockStore(initial: aRecord(wrongCount: 4));
      final container = boot(store: store);

      final wrong = await controllerOf(container).verifyPin(wrongPin);
      final refused = await controllerOf(container).verifyPin(correctPin);

      final rendered = <String>[
        wrong.toString(),
        refused.toString(),
        const PinLockAttemptAccepted().toString(),
        const PinLockAttemptAborted().toString(),
      ].join('\n');

      expect(rendered, isNot(contains(wrongPin)));
      expect(rendered, isNot(contains(correctPin)));
      expect(rendered, isNot(contains(correctHash)));
      expect(rendered, isNot(contains(salt)));
    });

    test('the fake store call log never records secret material', () async {
      final store = FakePinLockStore(initial: aRecord());
      final container = boot(store: store);
      await controllerOf(container).verifyPin(wrongPin);
      await controllerOf(container).verifyPin(correctPin);

      final rendered = store.callLog.join('\n');
      expect(rendered, isNot(contains(salt)));
      expect(rendered, isNot(contains(correctHash)));
      expect(rendered, isNot(contains(correctPin)));
    });
  });
}
