import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/analytics.dart';
import 'package:hayati_app/core/analytics/analytics_event.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/coach/domain/coach_exception.dart';
import 'package:hayati_app/features/coach/domain/coach_persona.dart';
import 'package:hayati_app/features/coach/domain/coach_register.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_repository_provider.dart';
import 'package:hayati_app/features/coach/presentation/state/coach_send_controller.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer_exception.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/presentation/state/paired_answer_controller.dart';
import 'package:hayati_app/features/daily_question/presentation/state/solo_answer_controller.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';
import 'package:hayati_app/features/pairing/presentation/state/invite_share_controller.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
// flutter_riverpod's curated export surface omits Override; riverpod_annotation
// exposes it (the app.dart precedent).
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../support/fake_auth_repository.dart';
import '../../support/fake_coach_repository.dart';
import '../../support/fake_couple_answers_repository.dart';
import '../../support/fake_invite_repository.dart';
import '../../support/fake_invite_share_launcher.dart';
import '../../support/fake_local_flag_store.dart';
import '../../support/fake_solo_answers_repository.dart';
import '../../support/recording_analytics_sink.dart';

/// The call sites (ADR-057 D6, sentinel B's behavioural half).
///
/// `funnel_call_site_sentinel_test.dart` proves a call site EXISTS for every
/// client event; it deliberately cannot prove the call sites are on the right
/// PATH — an `invite_sent` emitted from an error branch would satisfy it. That
/// is this file's job, and the shape of every test here is the same pair: the
/// happy path emits, and the failure path does not.
void main() {
  late RecordingAnalyticsSink sink;
  late FakeLocalFlagStore flags;

  setUp(() {
    sink = RecordingAnalyticsSink();
    flags = FakeLocalFlagStore();
  });

  List<Override> analyticsOverrides() => [
    analyticsSinkProvider.overrideWithValue(sink),
    localFlagStoreProvider.overrideWithValue(flags),
  ];

  group('invite_sent — InviteShareController.share', () {
    (ProviderContainer, FakeInviteShareLauncher) arrange() {
      final launcher = FakeInviteShareLauncher();
      final container = ProviderContainer(
        overrides: [
          ...analyticsOverrides(),
          inviteRepositoryProvider.overrideWith(
            (ref) => FakeInviteRepository(),
          ),
          inviteShareLauncherProvider.overrideWith((ref) => launcher),
        ],
      );
      addTearDown(container.dispose);
      return (container, launcher);
    }

    test('a completed share emits invite_sent', () async {
      final (container, _) = arrange();
      await container
          .read(inviteShareControllerProvider.notifier)
          .share('come and join me');
      expect(sink.names, ['invite_sent']);
    });

    test('two shares emit twice — this event is NOT de-duplicated', () async {
      final (container, _) = arrange();
      final controller = container.read(inviteShareControllerProvider.notifier);
      await controller.share('one');
      await controller.share('two');
      expect(sink.names, ['invite_sent', 'invite_sent']);
    });

    test('a share sheet that THREW emits nothing', () async {
      final (container, launcher) = arrange();
      launcher.onShareText = (_) => Future<void>.error(StateError('no sheet'));
      await expectLater(
        container.read(inviteShareControllerProvider.notifier).share('x'),
        throwsStateError,
      );
      expect(
        sink.names,
        isEmpty,
        reason: 'an invite nobody could send is not an invite sent',
      );
    });
  });

  group('q_answered{solo} — SoloAnswerController.save', () {
    (ProviderContainer, FakeSoloAnswersRepository) arrange() {
      final fake = FakeSoloAnswersRepository();
      final container = ProviderContainer(
        overrides: [
          ...analyticsOverrides(),
          soloAnswersRepositoryProvider.overrideWith((ref) => fake),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);
      return (container, fake);
    }

    test('a saved answer emits q_answered with mode solo', () async {
      final (container, _) = arrange();
      await container
          .read(soloAnswerControllerProvider.notifier)
          .save(
            uid: 'uid-1',
            dayKey: '20260818',
            questionId: 'solo_en_001',
            text: 'Hi',
          );
      expect(sink.names, ['q_answered']);
      expect(
        sink.events.whereType<QAnsweredEvent>().single.mode,
        AnalyticsAnswerMode.solo,
      );
    });

    test('editing the same day does not emit again', () async {
      final (container, _) = arrange();
      final controller = container.read(soloAnswerControllerProvider.notifier);
      await controller.save(
        uid: 'uid-1',
        dayKey: '20260818',
        questionId: 'solo_en_001',
        text: 'first',
      );
      await controller.save(
        uid: 'uid-1',
        dayKey: '20260818',
        questionId: 'solo_en_001',
        text: 'edited',
      );
      expect(sink.names, ['q_answered']);
    });

    // The regression the full suite caught, at a call site that had no test for
    // it. `ref.read` on an autoDispose controller THROWS once it is disposed,
    // and every one of these controllers concedes it can be disposed mid-flight
    // (that is what their own `ref.mounted` guards are for). The first version
    // of this diff read `analyticsProvider` AFTER the await at all four call
    // sites; only the coach one had a test that exercised disposal, so the
    // other three were latent. The Analytics handle is now captured before the
    // await everywhere — this proves it at one of the three.
    test('a save whose controller is disposed mid-flight still emits, and '
        'does not throw', () async {
      final (container, fake) = arrange();
      final gate = Completer<void>();
      fake.onSaveAnswer = (uid, dayKey, questionId, text) => gate.future;

      final sub = container.listen(soloAnswerControllerProvider, (_, _) {});
      final notifier = container.read(soloAnswerControllerProvider.notifier);
      final saving = notifier.save(
        uid: 'uid-1',
        dayKey: '20260818',
        questionId: 'solo_en_001',
        text: 'Hi',
      );

      // Dropping the last listener genuinely disposes an autoDispose element
      // (the coach test's precedent — `invalidate` on a listened element only
      // schedules a rebuild and leaves `ref.mounted` true, which would leave
      // this rule unexercised). Dispose is scheduled on a macrotask.
      sub.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        identical(
          container.read(soloAnswerControllerProvider.notifier),
          notifier,
        ),
        isFalse,
        reason:
            'the controller was not genuinely torn down, so this test '
            'proves nothing',
      );

      gate.complete();
      await saving;

      expect(sink.names, ['q_answered']);
    });

    test('a FAILED save emits nothing', () async {
      final (container, fake) = arrange();
      fake.onSaveAnswer = (uid, dayKey, questionId, text) =>
          Future<void>.error(const SoloAnswerUnknownException(code: 'boom'));
      await container
          .read(soloAnswerControllerProvider.notifier)
          .save(
            uid: 'uid-1',
            dayKey: '20260818',
            questionId: 'solo_en_001',
            text: 'Hi',
          );
      expect(sink.names, isEmpty);
    });
  });

  group('q_answered{mutual} — PairedAnswerController.save', () {
    (ProviderContainer, FakeCoupleAnswersRepository) arrange() {
      final fake = FakeCoupleAnswersRepository();
      final container = ProviderContainer(
        overrides: [
          ...analyticsOverrides(),
          coupleAnswersRepositoryProvider.overrideWith((ref) => fake),
        ],
      );
      addTearDown(container.dispose);
      return (container, fake);
    }

    test('a saved answer emits q_answered with mode mutual', () async {
      final (container, _) = arrange();
      await container
          .read(pairedAnswerControllerProvider.notifier)
          .save(
            coupleId: 'couple-1',
            dayKey: '20260818',
            uid: 'uid-1',
            questionId: 'q1',
            text: 'Hi',
          );
      expect(sink.names, ['q_answered']);
      expect(
        sink.events.whereType<QAnsweredEvent>().single.mode,
        AnalyticsAnswerMode.mutual,
      );
    });

    test('the two modes are counted separately on the same day', () async {
      // Same uid, same dayKey, different mode: the once-key includes the mode,
      // so a user who answers solo and then pairs is not silently deduped.
      final soloFake = FakeSoloAnswersRepository();
      addTearDown(soloFake.dispose);
      final container = ProviderContainer(
        overrides: [
          ...analyticsOverrides(),
          coupleAnswersRepositoryProvider.overrideWith(
            (ref) => FakeCoupleAnswersRepository(),
          ),
          soloAnswersRepositoryProvider.overrideWith((ref) => soloFake),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(soloAnswerControllerProvider.notifier)
          .save(
            uid: 'uid-1',
            dayKey: '20260818',
            questionId: 'q1',
            text: 'solo',
          );
      await container
          .read(pairedAnswerControllerProvider.notifier)
          .save(
            coupleId: 'couple-1',
            dayKey: '20260818',
            uid: 'uid-1',
            questionId: 'q1',
            text: 'mutual',
          );

      expect(sink.events.whereType<QAnsweredEvent>().map((e) => e.mode), [
        AnalyticsAnswerMode.solo,
        AnalyticsAnswerMode.mutual,
      ]);
    });
  });

  group('coach_msg — CoachSendController.send', () {
    // The transcript's late-exchange guard reads the auth seam (ADR-017 D3), so
    // every container here composes it — signed in as the turn's owner.
    (ProviderContainer, FakeCoachRepository) arrange() {
      final fake = FakeCoachRepository();
      final auth = FakeAuthRepository(
        initialUser: const AuthUser(uid: 'uid-1', displayName: 'Test'),
      );
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          ...analyticsOverrides(),
          coachRepositoryProvider.overrideWith((ref) => fake),
          authRepositoryProvider.overrideWith((ref) => auth),
        ],
      );
      addTearDown(container.dispose);
      return (container, fake);
    }

    Future<void> send(ProviderContainer container) => container
        .read(
          coachSendControllerProvider(
            'uid-1',
            'couple-1',
            CoachPersonaId.dateGenie,
          ).notifier,
        )
        .send(
          text: 'hello',
          language: ContentLanguage.en,
          register: CoachRegister.enNeutral,
        );

    test('an ordinary reply emits coach_msg KEEPING the persona', () async {
      final (container, _) = arrange();
      await send(container);
      expect(sink.names, ['coach_msg']);
      final event = sink.events.whereType<CoachMsgEvent>().single;
      expect(event.outcome, AnalyticsCoachOutcome.reply);
      expect(event.persona, AnalyticsPersona.dateGenie);
    });

    // The ADR-016 rule at the real call site, not just on the type: the server
    // returns `remaining` on the post-filter help path, so this fixture is the
    // one that would leak if the emitter forwarded what it was handed.
    test('a HELP reply emits coach_msg with the persona stripped', () async {
      final (container, fake) = arrange();
      fake.onSendMessage = (call) async => const CoachReply(
        kind: CoachReplyKind.help,
        text: 'Please contact a professional.',
        category: CoachCrisisCategory.selfHarm,
        remaining: CoachRemaining(daily: 28, monthly: 998),
      );
      await send(container);
      final event = sink.events.whereType<CoachMsgEvent>().single;
      expect(event.outcome, AnalyticsCoachOutcome.help);
      expect(
        event.persona,
        isNull,
        reason: 'ADR-016: crisis outcomes are never attributable',
      );
      expect(event.debugFields.keys, ['outcome']);
      expect('$event', isNot(contains('28')));
      expect('$event', isNot(contains('selfHarm')));
    });

    test('a FAILED send emits nothing', () async {
      final (container, fake) = arrange();
      fake.onSendMessage = (call) async =>
          throw const CoachUnavailableException();
      await send(container);
      expect(sink.names, isEmpty);
    });
  });
}
