import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'coach_repository.dart';

part 'coach_repository_provider.g.dart';

/// Provides the app's [CoachRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// Functions-backed implementation, and tests override it per container with a
/// fake. Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.
@Riverpod(keepAlive: true)
CoachRepository coachRepository(Ref ref) => throw StateError(
  'coachRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
