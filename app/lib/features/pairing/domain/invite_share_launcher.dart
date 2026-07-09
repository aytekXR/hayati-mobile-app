import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'invite_share_launcher.g.dart';

/// Seam over the system share sheet. The concrete adapter drives share_plus's
/// platform channel (which throws in the plain test VM), so the screen depends
/// on this interface and widget tests substitute a fake — no method channel is
/// ever hit under `flutter test`.
abstract interface class InviteShareLauncher {
  /// Presents the platform share sheet for [text] (the composed invite
  /// message). Resolves once the sheet has been handled or dismissed.
  Future<void> shareText(String text);
}

/// Provides the app's [InviteShareLauncher].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// share_plus-backed adapter, and tests override it per container with a fake.
@Riverpod(keepAlive: true)
InviteShareLauncher inviteShareLauncher(Ref ref) => throw StateError(
  'inviteShareLauncherProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
