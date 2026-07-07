import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_config.dart';

part 'app_config_provider.g.dart';

/// Provides the active flavor's [AppConfig].
///
/// Deliberately unimplemented at the base: each flavor entrypoint
/// (`main_dev.dart` / `main_prod.dart`) overrides it at the root
/// `ProviderScope`, and tests override it per container.
@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) => throw StateError(
  'appConfigProvider must be overridden in a flavor entrypoint '
  '(main_dev.dart / main_prod.dart).',
);
