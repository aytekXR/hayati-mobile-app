import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'push_token_repository.dart';

part 'push_token_repository_provider.g.dart';

/// Provides the app's [PushTokenRepository].
///
/// Unimplemented at the base, like `dataRightsRepositoryProvider`: the flavor
/// entrypoints override it with the Functions-backed implementation and tests
/// override it per container with a fake.
@Riverpod(keepAlive: true)
PushTokenRepository pushTokenRepository(Ref ref) => throw StateError(
  'pushTokenRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
