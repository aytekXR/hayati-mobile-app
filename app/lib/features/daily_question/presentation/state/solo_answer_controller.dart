import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/solo_answer_exception.dart';
import '../../domain/solo_answers_repository_provider.dart';

part 'solo_answer_controller.g.dart';

/// Save-flow state for the solo answer entry (idle → saving → idle |
/// failure). Success needs no state of its own: the saved doc flows back
/// through `soloAnswerProvider` and the screen shows the saved caption —
/// same shape as `CaptureState`.
sealed class SoloSaveState {
  const SoloSaveState();
}

final class SoloSaveIdle extends SoloSaveState {
  const SoloSaveIdle();
}

final class SoloSaveSaving extends SoloSaveState {
  const SoloSaveSaving();
}

final class SoloSaveFailure extends SoloSaveState {
  const SoloSaveFailure(this.failure);

  final SoloAnswerException failure;
}

/// Drives [SoloAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `ProfileCaptureController`: re-entrant saves are dropped
/// while one is in flight, and every await is followed by a `ref.mounted`
/// guard (Riverpod 3).
@riverpod
class SoloAnswerController extends _$SoloAnswerController {
  @override
  SoloSaveState build() => const SoloSaveIdle();

  Future<void> save({
    required String uid,
    required String dayKey,
    required String questionId,
    required String text,
  }) async {
    if (state is SoloSaveSaving) return;
    state = const SoloSaveSaving();
    try {
      await ref
          .read(soloAnswersRepositoryProvider)
          .saveAnswer(uid, dayKey, questionId: questionId, text: text);
      if (!ref.mounted) return;
      state = const SoloSaveIdle();
    } on SoloAnswerException catch (failure) {
      if (!ref.mounted) return;
      state = SoloSaveFailure(failure);
    }
  }
}
