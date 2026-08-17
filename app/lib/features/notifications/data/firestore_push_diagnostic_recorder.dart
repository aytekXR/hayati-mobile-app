import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/push_diagnostic.dart';

/// [PushDiagnosticRecorder] over `users/{uid}.pushDiagnostic` (ADR-049 D1/D3).
///
/// Thin adapter on the `FunctionsPushTokenRepository` mold, with the same
/// deliberate property: **nothing here throws.** Everything that decides — what
/// to record, when, and when to stay quiet — lives above the seam in
/// `PushTokenSync` and is proven on Linux with a fake (the ADR-042 D2 trade).
///
/// **`update`, never `set(..., merge: true)`, and that is the whole design of
/// this class.** A `set` on a missing document is a CREATE, and a `users/{uid}`
/// created by this path would carry no `createdAt` and no `status` — a broken
/// profile that `profileFromMap` throws on. `update` fails with `not-found`
/// instead, which is exactly the wanted semantics: annotate an existing profile,
/// or do nothing. `PushTokenSync` starts at sign-in and profile capture happens
/// later, so that window is ordinary rather than exotic.
///
/// The `at` stamp is `FieldValue.serverTimestamp()` because the rules require
/// `at == request.time`: a client clock must not be able to forge freshness.
class FirestorePushDiagnosticRecorder implements PushDiagnosticRecorder {
  FirestorePushDiagnosticRecorder({
    required this._firestore,
    void Function(String message)? onFailure,
  }) : _onFailure = onFailure ?? debugPrint;

  final FirebaseFirestore _firestore;
  final void Function(String message) _onFailure;

  @override
  Future<void> record(String uid, PushDiagnostic diagnostic) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'pushDiagnostic': {
          'state': diagnostic.state.name,
          if (diagnostic.detail != null) 'detail': diagnostic.detail!.name,
          'at': FieldValue.serverTimestamp(),
        },
      });
    } catch (failure) {
      // Both ordinary failures land here and BOTH are no-ops by design:
      //   * `not-found` — no profile document yet (see the class doc);
      //   * `permission-denied` — the write raced a sign-out, so there is no
      //     longer an account to annotate.
      // Record the code only, never the throwable's stringification: this runs
      // on a path that may reach a crash reporter, and the no-content rule holds
      // here as everywhere (ADR-016 D5).
      _onFailure(
        'PushDiagnosticRecorder.record failed: '
        '${failure is FirebaseException ? failure.code : failure.runtimeType}',
      );
    }
  }
}
