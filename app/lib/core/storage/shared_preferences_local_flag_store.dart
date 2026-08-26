import 'package:shared_preferences/shared_preferences.dart';

import 'local_flag_store.dart';

/// [LocalFlagStore] over [SharedPreferences] (ADR-017 Decision 4). The instance
/// is passed in — awaited ONCE at bootstrap via `SharedPreferences.getInstance()`
/// before `runHayati` — so [isSet] can read SYNCHRONOUSLY off the in-memory
/// cache `getInstance()` populates: the disclaimer gate needs a synchronous
/// answer to decide its first frame without a spinner. [set] writes through to
/// disk asynchronously.
class SharedPreferencesLocalFlagStore implements LocalFlagStore {
  const SharedPreferencesLocalFlagStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool isSet(LocalFlagKey key) => _prefs.getBool(key.value) ?? false;

  @override
  Future<void> set(LocalFlagKey key) => _prefs.setBool(key.value, true);

  @override
  Future<void> removeAccountScoped(String uid) async {
    // `getKeys()` is PLUGIN-wide, not seam-wide: it returns every preference any
    // package wrote through `shared_preferences`. The predicate is what bounds
    // the sweep — a foreign key would have to carry this uid as a dot segment to
    // be caught, and nothing on this device does (ADR-061 Consequences).
    final doomed = _prefs
        .getKeys()
        .where((key) => localFlagKeyBelongsTo(key, uid))
        .toList(growable: false);
    for (final key in doomed) {
      await _prefs.remove(key);
    }
  }
}
