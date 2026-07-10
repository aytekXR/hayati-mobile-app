import 'dart:async';

import 'package:hayati_app/features/daily_question/domain/couple_answer.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository.dart';

/// Hand-written fake for the reveal-gated answers seam (M3.3), following
/// [FakeSoloAnswersRepository]. The reveal invariant itself is SERVER-side
/// (rules) and the client mirror lives in `partnerSlotProvider`, so this
/// fake serves whatever is seeded/saved without gating — tests model a
/// denial explicitly with [emitError] and a `CoupleDataPermissionException`.
class FakeCoupleAnswersRepository implements CoupleAnswersRepository {
  FakeCoupleAnswersRepository({Map<String, CoupleAnswer>? initialAnswers})
    : _answers = {...?initialAnswers};

  /// Keyed `'$coupleId/$dayKey/$authorUid'`.
  final Map<String, CoupleAnswer> _answers;
  final Map<String, StreamController<CoupleAnswer?>> _controllers = {};

  /// Behaviour override for the next [saveAnswer] calls (e.g. to throw a
  /// [CoupleDataException] or hold a completer); default persists and emits
  /// like the real thing — with the server-acked stamp, so the partner-slot
  /// gate opens exactly as it would on a committed write.
  Future<void> Function(
    String coupleId,
    String dayKey,
    String authorUid,
    String questionId,
    String text,
  )?
  onSaveAnswer;

  int saveCalls = 0;
  final List<String> savedTexts = [];
  final List<String> savedQuestionIds = [];

  /// The server stamp the default save applies — fixed so goldens and
  /// equality assertions stay deterministic.
  static final answeredAtStamp = DateTime.utc(2026, 7, 10, 12);

  static String keyFor(String coupleId, String dayKey, String authorUid) =>
      '$coupleId/$dayKey/$authorUid';

  StreamController<CoupleAnswer?> _controllerFor(String key) =>
      _controllers.putIfAbsent(key, StreamController<CoupleAnswer?>.broadcast);

  /// Pushes an external answer event (the partner's device wrote the doc).
  void emitAnswer(
    String coupleId,
    String dayKey,
    String authorUid,
    CoupleAnswer? answer,
  ) {
    final key = keyFor(coupleId, dayKey, authorUid);
    if (answer == null) {
      _answers.remove(key);
    } else {
      _answers[key] = answer;
    }
    _controllerFor(key).add(answer);
  }

  /// Pushes a stream failure to [watchAnswer] listeners — a
  /// `CoupleDataPermissionException` here models the rules denying the
  /// partner watch (the client maps it back to the locked state).
  void emitError(
    String coupleId,
    String dayKey,
    String authorUid,
    Object error,
  ) {
    _controllerFor(keyFor(coupleId, dayKey, authorUid)).addError(error);
  }

  @override
  Stream<CoupleAnswer?> watchAnswer(
    String coupleId,
    String dayKey,
    String authorUid,
  ) async* {
    final key = keyFor(coupleId, dayKey, authorUid);
    yield _answers[key];
    // await-for (not yield*) so an emitted error TERMINATES this stream,
    // exactly like the real repository's generator.
    await for (final answer in _controllerFor(key).stream) {
      yield answer;
    }
  }

  @override
  Future<void> saveAnswer(
    String coupleId,
    String dayKey, {
    required String authorUid,
    required String questionId,
    required String text,
  }) async {
    saveCalls++;
    savedTexts.add(text);
    savedQuestionIds.add(questionId);
    final handler = onSaveAnswer;
    if (handler != null) {
      await handler(coupleId, dayKey, authorUid, questionId, text);
      return;
    }
    emitAnswer(
      coupleId,
      dayKey,
      authorUid,
      CoupleAnswer(
        questionId: questionId,
        text: text,
        answeredAt: answeredAtStamp,
      ),
    );
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
