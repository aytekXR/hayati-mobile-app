import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data_rights_repository.dart';

part 'data_rights_repository_provider.g.dart';

/// Provides the app's [DataRightsRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `coachRepositoryProvider` / `inviteRepositoryProvider`): the flavor
/// entrypoints override it with the Functions-backed implementation, and tests
/// override it per container with a fake. Use `overrideWith((ref) => …)` — the
/// repository is constructed per container, not a shared value.
@Riverpod(keepAlive: true)
DataRightsRepository dataRightsRepository(Ref ref) => throw StateError(
  'dataRightsRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
