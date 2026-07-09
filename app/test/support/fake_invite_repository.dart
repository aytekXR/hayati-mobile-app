import 'package:hayati_app/features/pairing/domain/invite_repository.dart';
import 'package:hayati_app/features/pairing/domain/issued_invite.dart';

/// Hand-written fake backing the pairing domain/presentation tests, in the
/// same behaviour-knob style as [FakeProfileRepository]: an [onCreateInvite]
/// hook overrides the outcome (throw an [InviteException], never complete, …),
/// a [createCalls] recorder proves re-issue/retry, and the default returns
/// [invite] so a screen that just needs a code renders without arrangement.
class FakeInviteRepository implements InviteRepository {
  FakeInviteRepository({IssuedInvite? invite})
    : invite =
          invite ??
          IssuedInvite(
            code: 'ABCD2345',
            expiresAt: DateTime(2026, 7, 11, 15, 30),
            reused: false,
          );

  /// The invite returned by [createInvite] when [onCreateInvite] is unset.
  final IssuedInvite invite;

  /// Behaviour override for the next [createInvite] calls; default returns
  /// [invite].
  Future<IssuedInvite> Function()? onCreateInvite;

  int createCalls = 0;

  @override
  Future<IssuedInvite> createInvite() {
    createCalls++;
    final handler = onCreateInvite;
    if (handler != null) return handler();
    return Future<IssuedInvite>.value(invite);
  }

  Future<void> dispose() async {}
}
