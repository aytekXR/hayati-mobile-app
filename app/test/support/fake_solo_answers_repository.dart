import 'dart:async';

import 'package:hayati_app/features/daily_question/domain/solo_answer.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answers_repository.dart';

/// Hand-written fake backing the solo-answer domain/presentation tests.
///
/// Contract fidelity matters here, exactly like [FakeProfileRepository]: a
/// [watchAnswer] subscription replays the CURRENT value immediately on
/// listen, then live updates — the solo home depends on that first emission
/// to leave its loading state, and the restart-persistence test seeds
/// [initialAnswers] to model a reinstall finding the Firestore doc.
class FakeSoloAnswersRepository implements SoloAnswersRepository {
  FakeSoloAnswersRepository({Map<String, SoloAnswer>? initialAnswers})
    : _answers = {...?initialAnswers};

  /// Keyed `'$uid/$dayKey'`.
  final Map<String, SoloAnswer> _answers;
  final Map<String, StreamController<SoloAnswer?>> _controllers = {};

  /// Behaviour override for the next [saveAnswer] calls (e.g. to throw a
  /// [SoloAnswerException] or hold a completer); default persists and emits
  /// like the real thing.
  Future<void> Function(
    String uid,
    String dayKey,
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

  static String keyFor(String uid, String dayKey) => '$uid/$dayKey';

  StreamController<SoloAnswer?> _controllerFor(String key) =>
      _controllers.putIfAbsent(key, StreamController<SoloAnswer?>.broadcast);

  /// Pushes an external answer event (another device wrote the doc).
  void emitAnswer(String uid, String dayKey, SoloAnswer? answer) {
    final key = keyFor(uid, dayKey);
    if (answer == null) {
      _answers.remove(key);
    } else {
      _answers[key] = answer;
    }
    _controllerFor(key).add(answer);
  }

  /// Pushes a stream failure (mapped SoloAnswerException) to [watchAnswer]
  /// listeners — the solo home's error state.
  void emitError(String uid, String dayKey, Object error) {
    _controllerFor(keyFor(uid, dayKey)).addError(error);
  }

  @override
  Stream<SoloAnswer?> watchAnswer(String uid, String dayKey) async* {
    final key = keyFor(uid, dayKey);
    yield _answers[key];
    // await-for (not yield*) so an emitted error TERMINATES this stream,
    // exactly like the real repository's generator.
    await for (final answer in _controllerFor(key).stream) {
      yield answer;
    }
  }

  @override
  Future<void> saveAnswer(
    String uid,
    String dayKey, {
    required String questionId,
    required String text,
  }) async {
    saveCalls++;
    savedTexts.add(text);
    savedQuestionIds.add(questionId);
    final handler = onSaveAnswer;
    if (handler != null) {
      await handler(uid, dayKey, questionId, text);
      return;
    }
    emitAnswer(
      uid,
      dayKey,
      SoloAnswer(
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
