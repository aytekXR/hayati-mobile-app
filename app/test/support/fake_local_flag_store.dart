import 'package:hayati_app/core/storage/local_flag_store.dart';

/// In-memory [LocalFlagStore] for tests — platform-channel-free by construction
/// (no `shared_preferences` mock needed). Flags are held in a plain set.
///
/// [initial] is seeded with the persisted key TEXT rather than [LocalFlagKey]s,
/// because that is what a real device holds and because it lets a test seed a
/// key by its literal string — which is how `analytics_test.dart` pins the six
/// analytics keys character for character.
class FakeLocalFlagStore implements LocalFlagStore {
  FakeLocalFlagStore({Set<String>? initial}) : _flags = {...?initial};

  final Set<String> _flags;

  /// What the store currently holds — the assertion surface for a sweep.
  Set<String> get keys => Set.unmodifiable(_flags);

  @override
  bool isSet(LocalFlagKey key) => _flags.contains(key.value);

  @override
  Future<void> set(LocalFlagKey key) async {
    _flags.add(key.value);
  }

  @override
  Future<void> removeAccountScoped(String uid) async {
    _flags.removeWhere((key) => localFlagKeyBelongsTo(key, uid));
  }
}
