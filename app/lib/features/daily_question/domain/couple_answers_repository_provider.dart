import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'couple_answers_repository.dart';

part 'couple_answers_repository_provider.g.dart';

/// Seam for [CoupleAnswersRepository]: bound to the Firestore implementation
/// at bootstrap (main_dev.dart / main_prod.dart), faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.
@Riverpod(keepAlive: true)
CoupleAnswersRepository coupleAnswersRepository(Ref ref) => throw StateError(
  'coupleAnswersRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
