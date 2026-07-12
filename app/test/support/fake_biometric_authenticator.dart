import 'dart:async';

import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';

/// Hand-written [BiometricAuthenticator] for the lock tests (ADR-018 Decision 1).
/// Scripted outcomes + a recorder.
///
/// What this fake CANNOT prove: that the real adapter asks for
/// biometrics-ONLY (`biometricOnly: true`, i.e. no device-passcode fallback —
/// blocking review finding TEST-1). A fake has no passcode to fall back to. That
/// guarantee is pinned separately by the source-sentinel test in
/// `test/features/privacy_lock/data/biometric_only_contract_test.dart`; this
/// fake only records THAT `authenticate` was called, and with what reason.
class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({
    this.available = true,
    this.enrollment = 'enrollment-v1',
    this.succeeds = true,
  });

  /// Scripted [isAvailable] / [enrollmentState] / [authenticate] outcomes.
  bool available;
  String? enrollment;
  bool succeeds;

  /// Ordered record of calls: `isAvailable`, `enrollmentState`,
  /// `authenticate:<reason>`.
  final List<String> callLog = [];

  /// Whether [authenticate] was ever invoked (the biometric flow ran at all).
  bool get authenticateCalled =>
      callLog.any((call) => call.startsWith('authenticate:'));

  /// Held open by a test to SUSPEND [authenticate] mid-prompt — the window in
  /// which a sign-out wipe can race the post-auth store write (the generation
  /// guard's other, more dangerous edge: unlike the wrong-attempt persist, this
  /// write is issued AFTER an await, so without the guard it would land after the
  /// clear and resurrect the record).
  Completer<void>? authenticateGate;

  /// Held open by a test to SUSPEND the two PROBE calls ([isAvailable],
  /// [enrollmentState]) that `refreshBiometricAvailability` awaits before it
  /// decides to revoke. That window is where a wrong-PIN persist can land — and
  /// where a revoke built on a pre-probe capture would refund the consumed
  /// attempt (the counter-refund race).
  Completer<void>? probeGate;

  @override
  Future<bool> isAvailable() async {
    callLog.add('isAvailable');
    final gate = probeGate;
    if (gate != null) await gate.future;
    return available;
  }

  @override
  Future<String?> enrollmentState() async {
    callLog.add('enrollmentState');
    final gate = probeGate;
    if (gate != null) await gate.future;
    return enrollment;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    callLog.add('authenticate:$reason');
    final gate = authenticateGate;
    if (gate != null) await gate.future;
    return succeeds;
  }
}
