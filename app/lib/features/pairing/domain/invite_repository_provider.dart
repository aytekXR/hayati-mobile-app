import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'invite_repository.dart';

part 'invite_repository_provider.g.dart';

/// Provides the app's [InviteRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `profileRepositoryProvider`): the flavor entrypoints override it with the
/// Functions-backed implementation, and tests override it per container with a
/// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.
@Riverpod(keepAlive: true)
InviteRepository inviteRepository(Ref ref) => throw StateError(
  'inviteRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
