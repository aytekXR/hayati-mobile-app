// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_lock_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(PrivacyLockController)
const privacyLockControllerProvider = PrivacyLockControllerProvider._();

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
final class PrivacyLockControllerProvider
    extends $NotifierProvider<PrivacyLockController, PrivacyLockState> {
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
  const PrivacyLockControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyLockControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyLockControllerHash();

  @$internal
  @override
  PrivacyLockController create() => PrivacyLockController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivacyLockState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivacyLockState>(value),
    );
  }
}

String _$privacyLockControllerHash() =>
    r'5b305f1884fcdfc1948fb1796986e31579bceff0';

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

abstract class _$PrivacyLockController extends $Notifier<PrivacyLockState> {
  PrivacyLockState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PrivacyLockState, PrivacyLockState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PrivacyLockState, PrivacyLockState>,
              PrivacyLockState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
