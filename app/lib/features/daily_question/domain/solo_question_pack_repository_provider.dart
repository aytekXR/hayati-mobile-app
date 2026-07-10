import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'solo_question_pack_repository.dart';

part 'solo_question_pack_repository_provider.g.dart';

/// Seam for [SoloQuestionPackRepository]: bound to the asset-backed
/// implementation at bootstrap (main_dev.dart / main_prod.dart), faked per
/// test container — same throw-until-overridden discipline as
/// `profileRepositoryProvider`.
@Riverpod(keepAlive: true)
SoloQuestionPackRepository soloQuestionPackRepository(Ref ref) =>
    throw StateError(
      'soloQuestionPackRepositoryProvider must be overridden at bootstrap '
      '(main_dev.dart / main_prod.dart) or per test container.',
    );
