import 'dart:async';

import 'package:hayati_app/core/storage/pin_lock_store.dart';

/// Hand-written in-memory [PinLockStore] backing every lock test (ADR-018
/// Decision 2 — the real `SecureStoragePinLockStore` is never imported by a test,
/// so `flutter test` never touches the Keychain channel and the device-only
/// adapter stays out of the coverage denominator).
///
/// Recorder style (the `FakePurchasesRepository` mold) with one deliberate rule:
/// **the [callLog] NEVER carries secret material.** A write logs PRESENCE only
/// (`write:set` / `write:empty`), exactly like `PinLockRecord.toString()` — a
/// test fixture that printed a salt would be the no-content rule leaking through
/// the back door.
///
/// Two knobs beyond the failure closures:
/// * [writeGate] — a [Completer] the test can hold open to SUSPEND a write
///   mid-flight. That is how the generation-guard race (the S019 class) is
///   provoked: a wrong-attempt persist is in flight when the sign-out wipe fires.
/// * operations are SERIALISED in call order (an internal future chain), the way
///   a single Keychain item behind one platform channel actually behaves — so a
///   `clear()` issued while a gated `write()` is parked lands AFTER it, and the
///   test observes the real ordering rather than a fake-only interleaving.
class FakePinLockStore implements PinLockStore {
  FakePinLockStore({PinLockRecord? initial}) : _record = initial;

  PinLockRecord? _record;
  Future<void> _tail = Future<void>.value();

  /// Ordered record of calls: `read`, `write:set` / `write:empty`, `clear`.
  /// Never a salt, hash, enrollment state, or PIN.
  final List<String> callLog = [];

  /// Held open by a test to suspend the NEXT (and every subsequent) write until
  /// it completes.
  Completer<void>? writeGate;

  /// Failure knobs — set to a throwing closure to prove a fail-direction.
  Future<void> Function()? onRead;
  Future<void> Function(PinLockRecord record)? onWrite;
  Future<void> Function()? onClear;

  /// What a "relaunch" (a fresh container over the same device) would read — the
  /// persisted truth, asserted directly by the bounding and race tests.
  PinLockRecord? get record => _record;

  @override
  Future<PinLockRecord?> read() => _serial(() async {
    callLog.add('read');
    final handler = onRead;
    if (handler != null) await handler();
    return _record;
  });

  @override
  Future<void> write(PinLockRecord record) => _serial(() async {
    callLog.add(record.isSet ? 'write:set' : 'write:empty');
    final gate = writeGate;
    if (gate != null) await gate.future;
    final handler = onWrite;
    if (handler != null) await handler(record);
    _record = record;
  });

  @override
  Future<void> clear() => _serial(() async {
    callLog.add('clear');
    final handler = onClear;
    if (handler != null) await handler();
    _record = null;
  });

  /// Queues [op] behind everything already issued (see the class doc).
  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    // The tail must survive a failing op, or one throw would wedge the queue.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
