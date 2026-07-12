import 'package:hayati_app/core/storage/local_flag_store.dart';

/// In-memory [LocalFlagStore] for tests — platform-channel-free by construction
/// (no `shared_preferences` mock needed). [set] flags are held in a plain set.
class FakeLocalFlagStore implements LocalFlagStore {
  FakeLocalFlagStore({Set<String>? initial}) : _flags = {...?initial};

  final Set<String> _flags;

  @override
  bool isSet(String key) => _flags.contains(key);

  @override
  Future<void> set(String key) async {
    _flags.add(key);
  }
}
