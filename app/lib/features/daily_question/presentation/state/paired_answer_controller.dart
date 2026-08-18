import 'package:hayati_app/core/analytics/analytics.dart';
import 'package:hayati_app/core/analytics/analytics_event.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/couple_answers_repository_provider.dart';
import '../../domain/couple_data_exception.dart';

part 'paired_answer_controller.g.dart';

/// Save-flow state for the paired answer entry (idle → saving → idle |
/// failure), mirroring `SoloSaveState`. Success needs no state of its own:
/// the saved doc flows back through `coupleAnswerProvider` and the reveal
/// pipeline reacts to the server ack.
sealed class PairedSaveState {
  const PairedSaveState();
}

final class PairedSaveIdle extends PairedSaveState {
  const PairedSaveIdle();
}

final class PairedSaveSaving extends PairedSaveState {
  const PairedSaveSaving();
}

final class PairedSaveFailure extends PairedSaveState {
  const PairedSaveFailure(this.failure);

  final CoupleDataException failure;
}

/// Drives [CoupleAnswersRepository.saveAnswer] with the same manual-op
/// discipline as `SoloAnswerController`: re-entrant saves are dropped while
/// one is in flight, and every await is followed by a `ref.mounted` guard.
@riverpod
class PairedAnswerController extends _$PairedAnswerController {
  @override
  PairedSaveState build() => const PairedSaveIdle();

  Future<void> save({
    required String coupleId,
    required String dayKey,
    required String uid,
    required String questionId,
    required String text,
  }) async {
    if (state is PairedSaveSaving) return;
    state = const PairedSaveSaving();
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
          .read(coupleAnswersRepositoryProvider)
          .saveAnswer(
            coupleId,
            dayKey,
            authorUid: uid,
            questionId: questionId,
            text: text,
          );
      // `q_answered{mutual}` (architecture.md §7). Same placement rule as the
      // solo twin: after the write resolves, before the ref.mounted guard.
      analytics.qAnswered(
        uid: uid,
        dayKey: dayKey,
        mode: AnalyticsAnswerMode.mutual,
      );
      if (!ref.mounted) return;
      state = const PairedSaveIdle();
    } on CoupleDataException catch (failure) {
      if (!ref.mounted) return;
      state = PairedSaveFailure(failure);
    }
  }
}
