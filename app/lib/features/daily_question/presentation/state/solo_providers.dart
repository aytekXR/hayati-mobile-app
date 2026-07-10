import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../profile/domain/relationship_profile.dart';
import '../../domain/question.dart';
import '../../domain/solo_answer.dart';
import '../../domain/solo_answers_repository_provider.dart';
import '../../domain/solo_question_pack_repository_provider.dart';

part 'solo_providers.g.dart';

/// Riverpod 3 auto-retry disabled: an error here is a malformed bundled
/// asset or a rules denial, where backoff-hammering just pins the screen on
/// a spinner. Recovery is the user-driven `ref.invalidate` on the error view.
Duration? _noRetry(int retryCount, Object error) => null;

/// The bundled solo pack for the profile's content language (M2.4). A family
/// keyed by [ContentLanguage] — same idiom as `invitePreviewProvider`.
/// AutoDispose: released when the solo home leaves the tree.
@Riverpod(retry: _noRetry)
Future<QuestionPack> soloQuestionPack(Ref ref, ContentLanguage language) =>
    ref.watch(soloQuestionPackRepositoryProvider).loadPack(language);

/// Live `users/{uid}/soloAnswers/{dayKey}` answer (null while unanswered).
/// A family keyed by uid + day key, mirroring `profileStreamProvider`'s
/// stream-consumer idiom.
@Riverpod(retry: _noRetry)
Stream<SoloAnswer?> soloAnswer(Ref ref, String uid, String dayKey) =>
    ref.watch(soloAnswersRepositoryProvider).watchAnswer(uid, dayKey);
