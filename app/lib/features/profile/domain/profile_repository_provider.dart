import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'profile_repository.dart';

part 'profile_repository_provider.g.dart';

/// Provides the app's [ProfileRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `authRepositoryProvider`): the flavor entrypoints override it with the
/// Firestore-backed implementation, and tests override it per container
/// with a fake. Use `overrideWith((ref) => …)` — the repository is
/// constructed per container, not a shared value.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => throw StateError(
  'profileRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
