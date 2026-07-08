import 'dart:async';

import 'package:hayati_app/features/profile/domain/profile_repository.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

/// Hand-written fake backing the profile domain/presentation tests.
///
/// Contract fidelity matters here: like Firestore `snapshots()`, a
/// [watchProfile] subscription replays the CURRENT value immediately on
/// listen, then live updates — the onboarding router depends on that first
/// emission to leave its loading state.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Map<String, RelationshipProfile>? initialProfiles})
    : _profiles = {...?initialProfiles};

  final Map<String, RelationshipProfile> _profiles;
  final Map<String, StreamController<RelationshipProfile?>> _controllers = {};

  /// Behaviour override for the next [saveProfile] calls (e.g. to throw a
  /// [ProfileException]); default persists and emits like the real thing.
  Future<void> Function(String uid, RelationshipProfile profile)? onSaveProfile;

  int saveCalls = 0;

  StreamController<RelationshipProfile?> _controllerFor(String uid) =>
      _controllers.putIfAbsent(
        uid,
        StreamController<RelationshipProfile?>.broadcast,
      );

  /// Pushes an external profile event (another device wrote the doc).
  void emitProfile(String uid, RelationshipProfile? profile) {
    if (profile == null) {
      _profiles.remove(uid);
    } else {
      _profiles[uid] = profile;
    }
    _controllerFor(uid).add(profile);
  }

  /// Pushes a stream failure (mapped ProfileException) to [watchProfile]
  /// listeners — the router's error state.
  void emitError(String uid, Object error) {
    _controllerFor(uid).addError(error);
  }

  @override
  Stream<RelationshipProfile?> watchProfile(String uid) async* {
    yield _profiles[uid];
    yield* _controllerFor(uid).stream;
  }

  @override
  Future<void> saveProfile(String uid, RelationshipProfile profile) async {
    saveCalls++;
    final handler = onSaveProfile;
    if (handler != null) {
      await handler(uid, profile);
      return;
    }
    emitProfile(uid, profile);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
