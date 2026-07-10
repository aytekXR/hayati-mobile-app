import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_data_exception.dart';
import 'package:hayati_app/features/daily_question/presentation/state/paired_answer_controller.dart';

import '../../../../support/fake_couple_answers_repository.dart';

void main() {
  (ProviderContainer, FakeCoupleAnswersRepository) arrange() {
    final fake = FakeCoupleAnswersRepository();
    final container = ProviderContainer(
      overrides: [coupleAnswersRepositoryProvider.overrideWith((ref) => fake)],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
    return (container, fake);
  }

  test('starts idle', () {
    final (container, _) = arrange();

    expect(
      container.read(pairedAnswerControllerProvider),
      isA<PairedSaveIdle>(),
    );
  });

  test('a save passes through saving and settles idle, delegating '
      'coupleId/dayKey/uid/questionId/text to the repository', () async {
    final (container, fake) = arrange();
    final controller = container.read(pairedAnswerControllerProvider.notifier);
    final gate = Completer<void>();
    String? seenCoupleId;
    String? seenDayKey;
    String? seenAuthorUid;
    String? seenQuestionId;
    fake.onSaveAnswer = (coupleId, dayKey, authorUid, questionId, text) {
      seenCoupleId = coupleId;
      seenDayKey = dayKey;
      seenAuthorUid = authorUid;
      seenQuestionId = questionId;
      return gate.future;
    };

    final save = controller.save(
      coupleId: 'couple-1',
      dayKey: '20260710',
      uid: 'uid-1',
      questionId: 'en_couple_001',
      text: 'Hi',
    );

    expect(
      container.read(pairedAnswerControllerProvider),
      isA<PairedSaveSaving>(),
    );

    gate.complete();
    await save;

    expect(
      container.read(pairedAnswerControllerProvider),
      isA<PairedSaveIdle>(),
    );
    expect(fake.saveCalls, 1);
    expect(seenCoupleId, 'couple-1');
    expect(seenDayKey, '20260710');
    expect(seenAuthorUid, 'uid-1');
    expect(seenQuestionId, 'en_couple_001');
    expect(fake.savedTexts, ['Hi']);
  });

  test('re-entrant saves are dropped while one is in flight', () async {
    final (container, fake) = arrange();
    final controller = container.read(pairedAnswerControllerProvider.notifier);
    final gate = Completer<void>();
    fake.onSaveAnswer = (coupleId, dayKey, authorUid, questionId, text) =>
        gate.future;

    final first = controller.save(
      coupleId: 'couple-1',
      dayKey: '20260710',
      uid: 'uid-1',
      questionId: 'en_couple_001',
      text: 'first',
    );

    // The held-open repository call keeps the controller in Saving; a second
    // save() landing in that window is dropped, not queued.
    expect(
      container.read(pairedAnswerControllerProvider),
      isA<PairedSaveSaving>(),
    );
    await controller.save(
      coupleId: 'couple-1',
      dayKey: '20260710',
      uid: 'uid-1',
      questionId: 'en_couple_001',
      text: 'second',
    );

    gate.complete();
    await first;

    expect(fake.saveCalls, 1);
    expect(fake.savedTexts, ['first']);
  });

  test('a CoupleDataException lands in the failure state', () async {
    final (container, fake) = arrange();
    fake.onSaveAnswer = (coupleId, dayKey, authorUid, questionId, text) async {
      throw const CoupleDataNetworkException(message: 'off');
    };

    await container
        .read(pairedAnswerControllerProvider.notifier)
        .save(
          coupleId: 'couple-1',
          dayKey: '20260710',
          uid: 'uid-1',
          questionId: 'en_couple_001',
          text: 'Hi',
        );

    final state = container.read(pairedAnswerControllerProvider);
    expect(state, isA<PairedSaveFailure>());
    expect(
      (state as PairedSaveFailure).failure,
      const CoupleDataNetworkException(message: 'off'),
    );
  });

  test('a save after a failure recovers to idle', () async {
    final (container, fake) = arrange();
    final controller = container.read(pairedAnswerControllerProvider.notifier);
    fake.onSaveAnswer = (coupleId, dayKey, authorUid, questionId, text) async {
      throw const CoupleDataNetworkException();
    };
    await controller.save(
      coupleId: 'couple-1',
      dayKey: '20260710',
      uid: 'uid-1',
      questionId: 'q',
      text: 'Hi',
    );
    expect(
      container.read(pairedAnswerControllerProvider),
      isA<PairedSaveFailure>(),
    );

    fake.onSaveAnswer = null;
    await controller.save(
      coupleId: 'couple-1',
      dayKey: '20260710',
      uid: 'uid-1',
      questionId: 'q',
      text: 'Hi again',
    );

    expect(
      container.read(pairedAnswerControllerProvider),
      isA<PairedSaveIdle>(),
    );
  });
}
