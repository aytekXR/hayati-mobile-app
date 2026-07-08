/// Domain identity of a signed-in partner. Pure Dart — the Firebase `User`
/// never crosses the domain boundary (docs/architecture.md §2).
class AuthUser {
  const AuthUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.uid == uid &&
          other.displayName == displayName &&
          other.email == email &&
          other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, displayName, email, photoUrl);

  @override
  String toString() => 'AuthUser(uid: $uid, email: $email)';
}
