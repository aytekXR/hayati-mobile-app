import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_repository.dart';

part 'auth_repository_provider.g.dart';

/// Provides the app's [AuthRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `appConfigProvider`): the flavor entrypoints override it with the
/// Firebase-backed implementation, and tests override it per container
/// with a fake. Use `overrideWith((ref) => …)` — the repository is
/// constructed per container, not a shared value.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => throw StateError(
  'authRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
