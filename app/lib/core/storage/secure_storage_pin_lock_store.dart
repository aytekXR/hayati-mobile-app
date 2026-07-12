import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_lock_store.dart';

/// The one Keychain key holding the lock record (ADR-018 Decision 2). One key,
/// one versioned JSON blob: reads/writes are atomic at the Keychain-item level
/// and the bootstrap read is a single round-trip.
const String kPinLockStorageKey = 'privacy_lock.v1';

/// [PinLockStore] over the iOS **Keychain** via `flutter_secure_storage`
/// (ADR-018 Decision 2).
///
/// WHY the Keychain and not prefs — two independent kills: (a) the REINSTALL
/// BYPASS — `SharedPreferences` dies on delete+reinstall but the Firebase Auth
/// session lives in the Keychain and survives, so a prefs-resident lock would
/// evaporate while the content session it guards came back; (b) prefs are
/// plaintext at rest in the sandbox and land in unencrypted local backups. The
/// lock and the session it guards now share fate. (Consequence, on purpose:
/// deleting and reinstalling the app does NOT shed the lock.)
///
/// `unlocked_this_device` is the strictest accessibility that works for us: the
/// app only reads at foreground launch, when the device is necessarily unlocked,
/// and `this_device` keeps the record out of iCloud/device backups so a PIN never
/// migrates to another phone. Documented relaxation if device testing surfaces an
/// access issue: `first_unlock_this_device`. **When a background launch mode ever
/// arrives (APNs, M6.2+), revisit this** — a locked-device background read of an
/// `unlocked_this_device` item fails and would hit the fail-open path (review
/// finding SEC-3).
///
/// Its own file, constructed ONLY in the entrypoints: `flutter test` never
/// imports it, so the plugin channel is never touched under test and this
/// device-only code stays out of the coverage denominator (review finding
/// TEST-5). The JSON codec it delegates to lives in `pin_lock_store.dart` and IS
/// unit-tested. Device verification is operator item 4.
class SecureStoragePinLockStore implements PinLockStore {
  const SecureStoragePinLockStore([
    this._storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  ]);

  final FlutterSecureStorage _storage;

  /// Null when absent, and null (not a throw) when the stored blob is malformed
  /// or carries an unknown version — "we cannot understand this record" reads as
  /// absent, and the boot path must never take a parse throw.
  ///
  /// A genuine PLATFORM read failure is deliberately allowed to THROW: only
  /// [readInitialLockSnapshot] catches it, and it needs to tell a clean absent
  /// record (final) from a degraded read (re-read on the first resume) — a
  /// swallow here would erase that distinction (D2, review finding SEC-3).
  @override
  Future<PinLockRecord?> read() async {
    final raw = await _storage.read(key: kPinLockStorageKey);
    if (raw == null) return null;
    return PinLockRecord.decode(raw);
  }

  @override
  Future<void> write(PinLockRecord record) =>
      _storage.write(key: kPinLockStorageKey, value: record.encode());

  @override
  Future<void> clear() => _storage.delete(key: kPinLockStorageKey);
}
