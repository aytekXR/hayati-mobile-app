import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer_exception.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/state/solo_answer_controller.dart';

import '../../../../support/fake_solo_answers_repository.dart';

void main() {
  (ProviderContainer, FakeSoloAnswersRepository) arrange() {
    final fake = FakeSoloAnswersRepository();
    final container = ProviderContainer(
      overrides: [soloAnswersRepositoryProvider.overrideWith((ref) => fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
    return (container, fake);
  }

  test('starts idle', () {
    final (container, _) = arrange();

    expect(container.read(soloAnswerControllerProvider), isA<SoloSaveIdle>());
  });

  test('a save passes through saving and settles idle, delegating to the '
      'repository', () async {
    final (container, fake) = arrange();
    final controller = container.read(soloAnswerControllerProvider.notifier);
    final gate = Completer<void>();
    fake.onSaveAnswer = (uid, dayKey, questionId, text) => gate.future;

    final save = controller.save(
      uid: 'uid-1',
      dayKey: '20260710',
      questionId: 'solo_en_001',
      text: 'Hi',
    );

    expect(container.read(soloAnswerControllerProvider), isA<SoloSaveSaving>());

    gate.complete();
    await save;

    expect(container.read(soloAnswerControllerProvider), isA<SoloSaveIdle>());
    expect(fake.saveCalls, 1);
    expect(fake.savedTexts, ['Hi']);
  });

  test('re-entrant saves are dropped while one is in flight', () async {
    final (container, fake) = arrange();
    final controller = container.read(soloAnswerControllerProvider.notifier);
    final gate = Completer<void>();
    fake.onSaveAnswer = (uid, dayKey, questionId, text) => gate.future;

    final first = controller.save(
      uid: 'uid-1',
      dayKey: '20260710',
      questionId: 'solo_en_001',
      text: 'first',
    );
    await controller.save(
      uid: 'uid-1',
      dayKey: '20260710',
      questionId: 'solo_en_001',
      text: 'second',
    );

    gate.complete();
    await first;

    expect(fake.saveCalls, 1);
    expect(fake.savedTexts, ['first']);
  });

  test('a SoloAnswerException lands in the failure state', () async {
    final (container, fake) = arrange();
    fake.onSaveAnswer = (uid, dayKey, questionId, text) async {
      throw const SoloAnswerNetworkException(message: 'off');
    };

    await container
        .read(soloAnswerControllerProvider.notifier)
        .save(
          uid: 'uid-1',
          dayKey: '20260710',
          questionId: 'solo_en_001',
          text: 'Hi',
        );

    final state = container.read(soloAnswerControllerProvider);
    expect(state, isA<SoloSaveFailure>());
    expect(
      (state as SoloSaveFailure).failure,
      const SoloAnswerNetworkException(message: 'off'),
    );
  });

  test('a save after a failure recovers to idle', () async {
    final (container, fake) = arrange();
    final controller = container.read(soloAnswerControllerProvider.notifier);
    fake.onSaveAnswer = (uid, dayKey, questionId, text) async {
      throw const SoloAnswerNetworkException();
    };
    await controller.save(
      uid: 'uid-1',
      dayKey: '20260710',
      questionId: 'q',
      text: 'Hi',
    );
    expect(
      container.read(soloAnswerControllerProvider),
      isA<SoloSaveFailure>(),
    );

    fake.onSaveAnswer = null;
    await controller.save(
      uid: 'uid-1',
      dayKey: '20260710',
      questionId: 'q',
      text: 'Hi again',
    );

    expect(container.read(soloAnswerControllerProvider), isA<SoloSaveIdle>());
  });
}
