import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'local_flag_key.dart';

export 'local_flag_key.dart';

part 'local_flag_store.g.dart';

/// A minimal on-device boolean-flag seam (ADR-017 Decision 4) — the app's first
/// local-persistence surface (the previously-empty `core/storage/` placeholder
/// existed for this). Deliberately tiny: one-way flags such as the per-device
/// coach disclaimer acknowledgement. [isSet] is synchronous so a widget can gate
/// its first frame from the flag without an async round-trip; [set] writes
/// through durably.
///
/// **The sticky contract, as amended by ADR-061.** ADR-017 D4 wrote this seam as
/// set-once, NEVER cleared, and `pin_lock_store.dart` still cites that as a
/// reason for its own design. It holds for everything that writes here: no
/// feature clears its own flag, and sign-out clears nothing at all. The single
/// exception is [removeAccountScoped] — an account deletion, which is the one
/// event that removes everything else the account owns too.
///
/// Keys are [LocalFlagKey] and not `String` **so that the account-or-device
/// question cannot be skipped**: a flag that reaches this seam has been
/// classified, because there is no other way to build one.
abstract interface class LocalFlagStore {
  /// Whether [key] has ever been [set] on this device.
  bool isSet(LocalFlagKey key);

  /// Marks [key] set, durably. Idempotent.
  Future<void> set(LocalFlagKey key);

  /// Removes every flag on this device that the account [uid] owns — the
  /// device-local half of the ADR-019 deletion cascade (ADR-061 Decision 1).
  ///
  /// Takes a **uid**, never a key: the operation is *"everything this account
  /// wrote"*, and expressing it that way is what keeps [DeviceFlag] exempt by
  /// construction rather than by an exemption list somebody maintains.
  ///
  /// Called from **the delete flow only**. It must never be reached from the
  /// app-root sign-out listener: both a deletion and an ordinary sign-out end in
  /// `AuthSignedOut`, so clearing there would re-show the coach disclaimer, the
  /// name step and the privacy spotlight to a user who merely signed out and
  /// back in (ADR-061 finding 4).
  ///
  /// An empty [uid] removes nothing. Idempotent; never throws for an account
  /// that owns no flags.
  Future<void> removeAccountScoped(String uid);
}

/// Provides the app's [LocalFlagStore].
///
/// Deliberately unimplemented at the base (the repository-seam discipline
/// everywhere else): the flavor entrypoints override it BY VALUE with a
/// `SharedPreferencesLocalFlagStore` built from an already-awaited
/// `SharedPreferences` instance (the entrypoints are async), and tests override
/// it with a `FakeLocalFlagStore`.
@Riverpod(keepAlive: true)
LocalFlagStore localFlagStore(Ref ref) => throw StateError(
  'localFlagStoreProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
