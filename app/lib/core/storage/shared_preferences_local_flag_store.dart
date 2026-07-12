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
  bool isSet(String key) => _prefs.getBool(key) ?? false;

  @override
  Future<void> set(String key) => _prefs.setBool(key, true);
}
