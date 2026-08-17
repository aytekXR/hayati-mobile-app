import 'package:flutter/foundation.dart' show immutable;

import 'push_registration.dart';

/// What the app DID, when it could not get this device a push token
/// (ADR-049 Decision 2).
///
/// **This is the resolution the UI deliberately does not have.** ADR-046 D2
/// merged *"permission granted but no token"* and *"the callable threw"* into the
/// single [PushRegistrationState.awaitingDeviceToken] on purpose: the person
/// holding the phone gets the same sentence and the same button either way. A
/// session needs them apart, because one indicts APNs and the other indicts the
/// server — and telling those two apart is the whole reason this field exists.
///
/// Every member names **what the app did**, never what the user meant. That is a
/// correctness rule rather than a style one: after the first install-time dialog
/// iOS answers `requestPermission()` from its standing record **without showing
/// anything**, so "the user declined" would be a confident wrong label — the
/// exact defect ADR-046 D2(a) records one level up.
///
/// The `name`s are **wire values** (they are written to `users/{uid}` and read by
/// `push_delivery_probe.py`), and they are gated in `firestore.rules`. Renaming a
/// member is a data migration, not a refactor; adding one without adding it to
/// the rules is caught by `push_diagnostic_vocabulary_parity_test.dart`.
enum PushDiagnosticDetail {
  /// The app called `requestPermission()` and was not granted. **The prompt path
  /// RAN** — which is the honest form of "did the tap happen". From here iOS
  /// Settings is the only door (ADR-046 D3).
  permissionRequestRefused,

  /// ADR-044's bounded capture loop ran to its end and produced no token, with
  /// permission held. APNs never answered — the link ADR-042 D5 left unverified
  /// and ADR-046 D6 hardened, or the `.p8` that no API can read.
  captureExhausted,

  /// A token existed and `registerPushToken` threw. The device is fine; the
  /// server leg is not. This is the #219 shape, and it is invisible in
  /// `fcmTokens` precisely because the write that would have recorded it failed.
  registerFailed,

  /// Reading the OS permission state itself threw. Suspect the messaging plugin
  /// seam rather than any link beyond it.
  ///
  /// It outranks [captureExhausted] wherever both are true: a permission read
  /// that threw is a sharper statement than a loop that merely ended.
  permissionUnreadable,
}

/// One device's self-report about its own push registration (ADR-049 D2), as it
/// is written to `users/{uid}.pushDiagnostic`.
///
/// **A claim, never evidence.** `fcmTokens` is server-owned, written from a token
/// the server verified, and remains the only thing that proves reachability. This
/// says what the device believes about itself, which is the one thing no
/// server-side instrument can observe — and which four sessions could not obtain
/// without asking the founder to look at a phone.
@immutable
final class PushDiagnostic {
  const PushDiagnostic({required this.state, this.detail});

  final PushRegistrationState state;

  /// The extra resolution, where there is any. Null is ordinary: `denied` read
  /// straight from the OS, or a plain `registered`, have nothing more to add.
  final PushDiagnosticDetail? detail;

  @override
  bool operator ==(Object other) =>
      other is PushDiagnostic && other.state == state && other.detail == detail;

  @override
  int get hashCode => Object.hash(state, detail);

  @override
  String toString() =>
      'PushDiagnostic(${state.name}${detail == null ? '' : ' / ${detail!.name}'})';
}

/// Records a device's [PushDiagnostic] where a SESSION can read it (ADR-049 D1).
///
/// **Deliberately not a callable, and not a method on `ProfileRepository`.**
///
/// Not a callable, because one of the facts this carries is *"the callable
/// threw"* — a diagnostic travelling over the transport it reports on is silent
/// in exactly the case it was built for. Firestore's transport is independent of
/// the Cloud Run callables, so [PushDiagnosticDetail.registerFailed] is
/// reportable *by the failure itself*.
///
/// Not `ProfileRepository`, whose contract is the onboarding profile and whose
/// errors are a `ProfileException` taxonomy the UI renders. This write has
/// neither: it is fire-and-forget telemetry that must never produce a
/// user-visible failure, and putting a never-throwing method inside a throwing
/// contract would hand every existing fake a method it has no business
/// implementing.
///
/// **Implementations never throw** — the `FunctionsPushTokenRepository` mold two
/// files away. A diagnostic that can throw into the boot path is a worse bug than
/// the blindness it cures (ADR-039 D1).
abstract interface class PushDiagnosticRecorder {
  /// Records [diagnostic] for [uid]. Never throws; a failure is a logged no-op.
  ///
  /// **Annotates an existing profile or does nothing** — it must never bring a
  /// `users/{uid}` document into existence (ADR-049 D3). `PushTokenSync` starts
  /// at sign-in and profile capture happens later, so on a new account the first
  /// diagnostic can fire before the document exists; a document created by this
  /// path would carry no `createdAt` (breaking the create-once server stamp) and
  /// no `status` (breaking `profileFromMap`, which throws on a missing enum field
  /// and would take the profile stream, and therefore the onboarding gate, down
  /// with it).
  Future<void> record(String uid, PushDiagnostic diagnostic);
}
