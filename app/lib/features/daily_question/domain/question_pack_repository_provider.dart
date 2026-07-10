import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'question_pack_repository.dart';

part 'question_pack_repository_provider.g.dart';

/// Seam for the generic by-packId [QuestionPackRepository] (M3.3 — the
/// paired home resolves the day's question text by the day doc's `packId`;
/// the solo path keeps its own locale-keyed specialization seam). Bound to
/// the asset-backed implementation at bootstrap, faked per test container —
/// same throw-until-overridden discipline as `profileRepositoryProvider`.
@Riverpod(keepAlive: true)
QuestionPackRepository questionPackRepository(Ref ref) => throw StateError(
  'questionPackRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
