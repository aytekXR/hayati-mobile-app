import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_exception.dart';
import '../domain/profile_repository.dart';
import '../domain/relationship_profile.dart';
import 'profile_dto.dart';

/// Firestore-backed [ProfileRepository] over `users/{uid}`
/// (docs/architecture.md §3). Every failure crossing this boundary is mapped
/// into the [ProfileException] taxonomy — anything else escaping is a bug
/// (same `_guarded` discipline as `FirebaseAuthRepository`).
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Stream<RelationshipProfile?> watchProfile(String uid) async* {
    try {
      // Firestore emits the current document immediately on listen, then
      // every change — the contract FakeProfileRepository mirrors.
      await for (final snapshot in _doc(uid).snapshots()) {
        final data = snapshot.data();
        yield data == null ? null : profileFromMap(data);
      }
    } catch (failure) {
      throw mapFirestoreFailure(failure);
    }
  }

  @override
  Future<void> saveProfile(String uid, RelationshipProfile profile) async {
    final doc = _doc(uid);
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(doc);
        final data = profileToMap(profile);
        if (!snapshot.exists) {
          // Create-once: the server stamps createdAt on first write and a
          // re-capture never rewrites it. (A pending server timestamp reads
          // back as null locally until the write is acked — the mapper
          // ignores createdAt entirely, so the UI never sees that window.)
          data['createdAt'] = FieldValue.serverTimestamp();
        }
        // merge keeps server-owned fields (coupleId, fcmTokens — M2+)
        // intact when the profile is edited.
        transaction.set(doc, data, SetOptions(merge: true));
      });
    } catch (failure) {
      throw mapFirestoreFailure(failure);
    }
  }
}

/// Boundary enforcement for the Firestore error surface: transient
/// availability → network (retry is honest advice), rules/auth denial →
/// permission (retry is not), everything else keeps its raw code.
ProfileException mapFirestoreFailure(Object failure) {
  if (failure is ProfileException) return failure;
  if (failure is FirebaseException) {
    return switch (failure.code) {
      'unavailable' ||
      'deadline-exceeded' => ProfileNetworkException(message: failure.message),
      'permission-denied' ||
      'unauthenticated' => ProfilePermissionException(message: failure.message),
      _ => ProfileUnknownException(
        code: failure.code,
        message: failure.message,
      ),
    };
  }
  return ProfileUnknownException(code: 'unexpected', message: '$failure');
}
