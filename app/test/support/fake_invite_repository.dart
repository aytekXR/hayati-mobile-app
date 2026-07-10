import 'package:hayati_app/features/pairing/domain/invite_repository.dart';
import 'package:hayati_app/features/pairing/domain/issued_invite.dart';

/// Hand-written fake backing the pairing domain/presentation tests, in the
/// same behaviour-knob style as [FakeProfileRepository]: [onCreateInvite] /
/// [onJoinInvite] hooks override the outcome (throw an [InviteException], never
/// complete, …), [createCalls] / [joinCalls] recorders prove re-issue/retry/
/// double-submit guards, and the defaults return [invite] / [coupleId] so a
/// screen that just needs a happy path renders without arrangement.
class FakeInviteRepository implements InviteRepository {
  FakeInviteRepository({IssuedInvite? invite, this.coupleId = 'couple-1'})
    : invite =
          invite ??
          IssuedInvite(
            code: 'ABCD2345',
            expiresAt: DateTime(2026, 7, 11, 15, 30),
            reused: false,
          );

  /// The invite returned by [createInvite] when [onCreateInvite] is unset.
  final IssuedInvite invite;

  /// The couple id returned by [joinInvite] when [onJoinInvite] is unset.
  final String coupleId;

  /// Behaviour override for the next [createInvite] calls; default returns
  /// [invite].
  Future<IssuedInvite> Function()? onCreateInvite;

  /// Behaviour override for the next [joinInvite] calls; default returns
  /// [coupleId]. Receives the code so a test can assert what was submitted.
  Future<String> Function(String code)? onJoinInvite;

  int createCalls = 0;
  int joinCalls = 0;

  /// The codes passed to [joinInvite], in order — proves the controller
  /// forwards exactly what the screen submitted.
  final List<String> joinedCodes = [];

  @override
  Future<IssuedInvite> createInvite() {
    createCalls++;
    final handler = onCreateInvite;
    if (handler != null) return handler();
    return Future<IssuedInvite>.value(invite);
  }

  @override
  Future<String> joinInvite(String code) {
    joinCalls++;
    joinedCodes.add(code);
    final handler = onJoinInvite;
    if (handler != null) return handler(code);
    return Future<String>.value(coupleId);
  }

  Future<void> dispose() async {}
}
