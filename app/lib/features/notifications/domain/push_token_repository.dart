/// The client half of ADR-042 Decision 1's two callables.
///
/// `users/{uid}.fcmTokens` is server-owned — `firestore.rules` forbids a client
/// from minting it at create or touching it at update — so these two calls are
/// the only way a token reaches a user document.
abstract interface class PushTokenRepository {
  /// Registers [token] to the signed-in caller, and evicts it from every other
  /// user document that carries it.
  ///
  /// That eviction is why this is a callable rather than a direct write: a token
  /// addresses a DEVICE and a user does not, so when this user signs in on a
  /// phone someone else signed out of, the previous owner must lose it — a
  /// cross-document write no client may ever make.
  Future<void> register(String token);

  /// Removes [token] from the signed-in caller and from nobody else.
  ///
  /// Best-effort by design: registration is what repairs the world, so nothing
  /// depends on this having run. A killed app, a revoked session and a phone in
  /// a drawer all skip it.
  Future<void> unregister(String token);
}
