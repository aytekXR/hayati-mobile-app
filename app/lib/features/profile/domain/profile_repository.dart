import 'profile_exception.dart';
import 'relationship_profile.dart';

/// Persistence contract for the onboarding profile (`users/{uid}`,
/// docs/architecture.md §3). Implementations map their errors into the
/// [ProfileException] taxonomy; anything else escaping is a bug.
abstract interface class ProfileRepository {
  /// Emits the current profile immediately on listen (null when the user has
  /// never completed capture), then every change — including writes from the
  /// user's other devices.
  Stream<RelationshipProfile?> watchProfile(String uid);

  /// Creates or fully replaces the caller's own profile document. Server-owned
  /// fields (createdAt) are managed by the implementation, never the caller.
  Future<void> saveProfile(String uid, RelationshipProfile profile);
}
