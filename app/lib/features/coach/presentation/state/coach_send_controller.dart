import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../profile/domain/relationship_profile.dart';
import '../../domain/coach_exception.dart';
import '../../domain/coach_persona.dart';
import '../../domain/coach_register.dart';
import '../../domain/coach_repository_provider.dart';
import '../../domain/coach_window.dart';
import 'coach_transcript.dart';

part 'coach_send_controller.g.dart';

/// Send-flow state for one persona conversation (ADR-017 Decision 8), mirroring
/// `SoloSaveState`. Success needs no state of its own: the reply lands in the
/// transcript family; the controller returns to idle.
sealed class CoachSendState {
  const CoachSendState();
}

final class CoachSendIdle extends CoachSendState {
  const CoachSendIdle();
}

final class CoachSendSending extends CoachSendState {
  const CoachSendSending();
}

final class CoachSendFailure extends CoachSendState {
  const CoachSendFailure(this.failure);

  final CoachException failure;
}

/// Drives [CoachRepository.sendMessage] for ONE persona conversation with the
/// manual-op discipline of `SoloAnswerController` (ADR-017 Decision 8). An
/// autoDispose family keyed `(uid, coupleId, personaId)` — the same key as the
/// transcript — so persona A's in-flight send never blocks persona B.
///
/// The transcript append SURVIVES controller disposal: [send] captures the
/// persona's keepAlive [CoachTranscript] notifier AND its current entries BEFORE
/// the await, so a mid-send persona switch (which autoDisposes THIS controller)
/// still lands the paid-for reply — and its latch/hint effects — in the right
/// conversation. `ref.mounted` guards ONLY this controller's OWN state writes.
@riverpod
class CoachSendController extends _$CoachSendController {
  @override
  CoachSendState build(String uid, String coupleId, CoachPersonaId personaId) =>
      const CoachSendIdle();

  /// Sends [text] as the next user turn. Re-entrant sends are dropped while one
  /// is in flight (per persona). Catches ONLY [CoachException] — the repository
  /// is total over that taxonomy, so nothing else should escape; on failure the
  /// draft is kept (retry = tap send again, no auto-retry) and the transcript is
  /// untouched.
  Future<void> send({
    required String text,
    required ContentLanguage language,
    required CoachRegister register,
  }) async {
    if (state is CoachSendSending) return;
    state = const CoachSendSending();

    // Capture the keepAlive transcript notifier AND its current entries BEFORE
    // the await (ADR-017 Decision 8): the keepAlive notifier outlives this
    // autoDispose controller, so applying the exchange through this captured
    // reference works even if a mid-send persona switch disposed us.
    final transcript = ref.read(
      coachTranscriptProvider(uid, coupleId, personaId).notifier,
    );
    final entries = ref
        .read(coachTranscriptProvider(uid, coupleId, personaId))
        .entries;
    final repository = ref.read(coachRepositoryProvider);
    final window = buildCoachWindow(entries: entries, newUserText: text);

    try {
      final reply = await repository.sendMessage(
        coupleId: coupleId,
        personaId: personaId,
        language: language,
        register: register,
        messages: window,
      );
      // Land the reply FIRST, through the captured (keepAlive) reference — this
      // must happen even if `ref.mounted` is now false (controller disposed).
      transcript.applyExchange(userText: text, reply: reply);
      if (!ref.mounted) return;
      state = const CoachSendIdle();
    } on CoachException catch (failure) {
      if (!ref.mounted) return;
      state = CoachSendFailure(failure);
    }
  }
}
