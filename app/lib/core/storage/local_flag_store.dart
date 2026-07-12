import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_flag_store.g.dart';

/// A minimal on-device boolean-flag seam (ADR-017 Decision 4) — the app's first
/// local-persistence surface (the previously-empty `core/storage/` placeholder
/// existed for this). Deliberately tiny: one-way STICKY flags (set-once, never
/// cleared) such as the per-device coach disclaimer acknowledgement. [isSet] is
/// synchronous so a widget can gate its first frame from the flag without an
/// async round-trip; [set] writes through durably.
abstract interface class LocalFlagStore {
  /// Whether [key] has ever been [set] on this device.
  bool isSet(String key);

  /// Marks [key] set, durably. Idempotent.
  Future<void> set(String key);
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
