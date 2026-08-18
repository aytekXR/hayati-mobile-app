import 'package:hayati_app/core/analytics/analytics.dart';
import 'package:hayati_app/core/analytics/analytics_event.dart';
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
    // Captured BEFORE the await: `ref.read` on an autoDispose controller
    // THROWS once it is disposed, and this one can be disposed mid-flight —
    // its own `ref.mounted` guard below concedes exactly that. The Analytics
    // instance itself is keepAlive, so emitting through the captured handle
    // is safe from anywhere. (Found by ADR-017 D8's disposed-mid-send test,
    // which is the only place the repo already exercised this; the other
    // three call sites had the same latent defect and no test to reveal it.)
    final analytics = ref.read(analyticsProvider);
    try {
      await ref
          .read(soloAnswersRepositoryProvider)
          .saveAnswer(uid, dayKey, questionId: questionId, text: text);
      // `q_answered{solo}` (architecture.md §7) — after the save resolves, so a
      // failed write is not counted as an answer, and BEFORE the ref.mounted
      // guard, because a controller disposed mid-save still saved. Once per
      // (uid, dayKey, solo) so an edit does not inflate the count (ADR-057 D4).
      analytics.qAnswered(
        uid: uid,
        dayKey: dayKey,
        mode: AnalyticsAnswerMode.solo,
      );
      if (!ref.mounted) return;
      state = const SoloSaveIdle();
    } on SoloAnswerException catch (failure) {
      if (!ref.mounted) return;
      state = SoloSaveFailure(failure);
    }
  }
}
