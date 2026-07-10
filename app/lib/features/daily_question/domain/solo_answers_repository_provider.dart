import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'solo_answers_repository.dart';

part 'solo_answers_repository_provider.g.dart';

/// Seam for [SoloAnswersRepository]: bound to the Firestore implementation at
/// bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.
@Riverpod(keepAlive: true)
SoloAnswersRepository soloAnswersRepository(Ref ref) => throw StateError(
  'soloAnswersRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
