import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answer.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_data_exception.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_assignment.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/state/paired_providers.dart';
import 'package:hayati_app/features/daily_question/presentation/state/partner_slot.dart';

import '../../../../support/fake_couple_answers_repository.dart';
import '../../../../support/fake_couple_day_repository.dart';
import '../../../../support/fake_couple_repository.dart';
import '../../../../support/fake_question_pack_repository.dart';

/// Records every [watchAnswer] authorUid before delegating to super — so a
/// test can prove *structurally* (not just by resulting state) that the
/// partner's answer watch is NEVER attached while the slot is Locked. The
/// client half of the reveal invariant is exactly this attach-gate: the
/// partner listen must not exist until the own answer is server-acked.
class RecordingCoupleAnswersRepository extends FakeCoupleAnswersRepository {
  RecordingCoupleAnswersRepository({super.initialAnswers});

  final List<String> watchedAuthorUids = [];

  @override
  Stream<CoupleAnswer?> watchAnswer(
    String coupleId,
    String dayKey,
    String authorUid,
  ) {
    watchedAuthorUids.add(authorUid);
    return super.watchAnswer(coupleId, dayKey, authorUid);
  }
}

void main() {
  const coupleId = 'couple-1';
  const dayKey = '20260710';
  const ownUid = 'uid-own';
  const partnerUid = 'uid-partner';
  const questionId = 'solo_tr_001';

  // The partner-slot provider family entry every gate test reads.
  final slot = partnerSlotProvider(
    coupleId: coupleId,
    dayKey: dayKey,
    ownUid: ownUid,
    partnerUid: partnerUid,
  );

  // A committed write's non-null server stamp — the ack the gate waits for.
  final ackedAt = DateTime.utc(2026, 7, 10, 12);

  ({
    ProviderContainer container,
    FakeCoupleRepository couples,
    FakeCoupleDayRepository days,
    FakeCoupleAnswersRepository answers,
  })
  arrange({
    FakeCoupleRepository? couples,
    FakeCoupleDayRepository? days,
    FakeCoupleAnswersRepository? answers,
  }) {
    final coupleRepo = couples ?? FakeCoupleRepository();
    final dayRepo = days ?? FakeCoupleDayRepository();
    final answerRepo = answers ?? FakeCoupleAnswersRepository();
    final container = ProviderContainer(
      overrides: [
        coupleRepositoryProvider.overrideWith((ref) => coupleRepo),
        coupleDayRepositoryProvider.overrideWith((ref) => dayRepo),
        coupleAnswersRepositoryProvider.overrideWith((ref) => answerRepo),
        // Nothing under test resolves the pack, but the container stays fully
        // wired so no seam falls back to its throw-until-overridden default.
        questionPackRepositoryProvider.overrideWith(
          (ref) => FakeQuestionPackRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(coupleRepo.dispose);
    addTearDown(dayRepo.dispose);
    addTearDown(answerRepo.dispose);
    return (
      container: container,
      couples: coupleRepo,
      days: dayRepo,
      answers: answerRepo,
    );
  }

  // Keeps the slot's dependency subscriptions warm so the streams settle and
  // the provider recomputes on each emission (mirrors pending_invite_test).
  void keepSlotAlive(ProviderContainer container) =>
      container.listen(slot, (_, _) {});

  group('partnerSlot — the client half of the reveal invariant', () {
    test('is Locked while the own answer doc is absent', () async {
      final env = arrange();
      keepSlotAlive(env.container);
      await pumpEventQueue();

      expect(env.container.read(slot), isA<PartnerSlotLocked>());
    });

    test('is Locked while the own answer exists but is not server-acked '
        '(answeredAt == null — a pending serverTimestamp echo)', () async {
      final env = arrange(
        answers: FakeCoupleAnswersRepository(
          initialAnswers: {
            FakeCoupleAnswersRepository.keyFor(coupleId, dayKey, ownUid):
                const CoupleAnswer(questionId: questionId, text: 'mine'),
          },
        ),
      );
      keepSlotAlive(env.container);
      await pumpEventQueue();

      expect(env.container.read(slot), isA<PartnerSlotLocked>());
    });

    test('never attaches the partner watch while Locked, then attaches it '
        'once the own answer is acked', () async {
      // Own is present-but-pending; partner is ALREADY committed. The partner
      // doc existing makes the gate's proof strongest: it must stay unwatched
      // purely because the own answer has not acked yet.
      final partnerAnswer = CoupleAnswer(
        questionId: questionId,
        text: 'theirs',
        answeredAt: ackedAt,
      );
      final recording = RecordingCoupleAnswersRepository(
        initialAnswers: {
          FakeCoupleAnswersRepository.keyFor(coupleId, dayKey, ownUid):
              const CoupleAnswer(questionId: questionId, text: 'mine'),
          FakeCoupleAnswersRepository.keyFor(coupleId, dayKey, partnerUid):
              partnerAnswer,
        },
      );
      final env = arrange(answers: recording);
      keepSlotAlive(env.container);
      await pumpEventQueue();

      // Pre-ack: Locked, and the partner uid was NEVER passed to watchAnswer.
      expect(env.container.read(slot), isA<PartnerSlotLocked>());
      expect(recording.watchedAuthorUids, contains(ownUid));
      expect(recording.watchedAuthorUids, isNot(contains(partnerUid)));

      // The own write commits (server stamp lands) — the gate opens.
      env.answers.emitAnswer(
        coupleId,
        dayKey,
        ownUid,
        CoupleAnswer(questionId: questionId, text: 'mine', answeredAt: ackedAt),
      );
      await pumpEventQueue();

      // Post-ack: the partner watch is now attached and the doc reveals.
      expect(recording.watchedAuthorUids, contains(partnerUid));
      expect(env.container.read(slot), PartnerSlotRevealed(partnerAnswer));
    });

    test(
      'is Waiting once the own answer is acked and the partner is absent',
      () async {
        final env = arrange(
          answers: FakeCoupleAnswersRepository(
            initialAnswers: {
              FakeCoupleAnswersRepository.keyFor(
                coupleId,
                dayKey,
                ownUid,
              ): CoupleAnswer(
                questionId: questionId,
                text: 'mine',
                answeredAt: ackedAt,
              ),
            },
          ),
        );
        keepSlotAlive(env.container);
        await pumpEventQueue();

        expect(env.container.read(slot), isA<PartnerSlotWaiting>());
      },
    );

    test('is Revealed(partnerAnswer) once both answers exist', () async {
      final partnerAnswer = CoupleAnswer(
        questionId: questionId,
        text: 'theirs',
        answeredAt: ackedAt,
      );
      final env = arrange(
        answers: FakeCoupleAnswersRepository(
          initialAnswers: {
            FakeCoupleAnswersRepository.keyFor(
              coupleId,
              dayKey,
              ownUid,
            ): CoupleAnswer(
              questionId: questionId,
              text: 'mine',
              answeredAt: ackedAt,
            ),
            FakeCoupleAnswersRepository.keyFor(coupleId, dayKey, partnerUid):
                partnerAnswer,
          },
        ),
      );
      keepSlotAlive(env.container);
      await pumpEventQueue();

      expect(env.container.read(slot), PartnerSlotRevealed(partnerAnswer));
    });

    test('maps a permission denial on the partner watch to Locked '
        '(defense-in-depth, never a Failure card)', () async {
      final env = arrange(
        answers: FakeCoupleAnswersRepository(
          initialAnswers: {
            FakeCoupleAnswersRepository.keyFor(
              coupleId,
              dayKey,
              ownUid,
            ): CoupleAnswer(
              questionId: questionId,
              text: 'mine',
              answeredAt: ackedAt,
            ),
          },
        ),
      );
      keepSlotAlive(env.container);
      await pumpEventQueue();
      // Own acked, partner absent → the partner watch is attached (Waiting).
      expect(env.container.read(slot), isA<PartnerSlotWaiting>());

      // Rules deny the partner listen (the lost exists()-race). No fake time
      // is advanced, so the bounded permission retry (1s+) never fires here —
      // the denial holds and the gate falls back to Locked.
      env.answers.emitError(
        coupleId,
        dayKey,
        partnerUid,
        const CoupleDataPermissionException(message: 'denied'),
      );
      await pumpEventQueue();

      expect(env.container.read(slot), isA<PartnerSlotLocked>());
    });

    test('maps a non-permission error on the partner watch to '
        'PartnerSlotFailure carrying it', () async {
      final env = arrange(
        answers: FakeCoupleAnswersRepository(
          initialAnswers: {
            FakeCoupleAnswersRepository.keyFor(
              coupleId,
              dayKey,
              ownUid,
            ): CoupleAnswer(
              questionId: questionId,
              text: 'mine',
              answeredAt: ackedAt,
            ),
          },
        ),
      );
      keepSlotAlive(env.container);
      await pumpEventQueue();

      // A network error is not permission → no retry, terminal error surface.
      env.answers.emitError(
        coupleId,
        dayKey,
        partnerUid,
        const CoupleDataNetworkException(message: 'offline'),
      );
      await pumpEventQueue();

      final state = env.container.read(slot);
      expect(state, isA<PartnerSlotFailure>());
      expect(
        (state as PartnerSlotFailure).failure,
        const CoupleDataNetworkException(message: 'offline'),
      );
    });
  });

  group('couple & day streams — honest nulls and un-retried errors', () {
    test(
      'a missing couple streams null (corrupt-state guard is the caller\'s)',
      () async {
        final env = arrange();
        // Hold the stream open — a bare `.future` read would auto-dispose the
        // provider mid-load before the fake's first (null) emission arrives.
        env.container.listen(coupleProvider(coupleId), (_, _) {});

        expect(
          await env.container.read(coupleProvider(coupleId).future),
          isNull,
        );
      },
    );

    test(
      'an unassigned day streams null (the honest no-day-yet state)',
      () async {
        final env = arrange();
        env.container.listen(
          coupleDayAssignmentProvider(coupleId, dayKey),
          (_, _) {},
        );

        expect(
          await env.container.read(
            coupleDayAssignmentProvider(coupleId, dayKey).future,
          ),
          isNull,
        );
      },
    );

    test(
      'a couple emitError surfaces as an AsyncError and is not retried',
      () async {
        const couple = Couple(
          id: coupleId,
          memberUids: [ownUid, partnerUid],
          timezone: 'Europe/Istanbul',
        );
        final env = arrange(
          couples: FakeCoupleRepository(initialCouples: {coupleId: couple}),
        );
        // Keep the stream alive past its first emission so the error propagates.
        env.container.listen(coupleProvider(coupleId), (_, _) {});
        await pumpEventQueue();
        expect(env.container.read(coupleProvider(coupleId)).value, couple);

        env.couples.emitError(
          coupleId,
          const CoupleDataNetworkException(message: 'off'),
        );
        await pumpEventQueue();

        final snap = env.container.read(coupleProvider(coupleId));
        expect(snap.hasError, isTrue);
        expect(snap.error, const CoupleDataNetworkException(message: 'off'));

        // _noRetry: the errored stream is terminal — a retry would re-listen and
        // replay the still-stored couple as data, flipping this back to a value.
        await pumpEventQueue();
        expect(env.container.read(coupleProvider(coupleId)).hasError, isTrue);
      },
    );

    test(
      'a day emitError surfaces as an AsyncError and is not retried',
      () async {
        const assignment = CoupleDayAssignment(
          questionId: questionId,
          packId: 'solo_tr',
          packVersion: 1,
        );
        final env = arrange(
          days: FakeCoupleDayRepository(
            initialDays: {
              FakeCoupleDayRepository.keyFor(coupleId, dayKey): assignment,
            },
          ),
        );
        env.container.listen(
          coupleDayAssignmentProvider(coupleId, dayKey),
          (_, _) {},
        );
        await pumpEventQueue();
        expect(
          env.container
              .read(coupleDayAssignmentProvider(coupleId, dayKey))
              .value,
          assignment,
        );

        env.days.emitError(
          coupleId,
          dayKey,
          const CoupleDataNetworkException(message: 'off'),
        );
        await pumpEventQueue();

        final snap = env.container.read(
          coupleDayAssignmentProvider(coupleId, dayKey),
        );
        expect(snap.hasError, isTrue);
        expect(snap.error, const CoupleDataNetworkException(message: 'off'));
      },
    );
  });
}
