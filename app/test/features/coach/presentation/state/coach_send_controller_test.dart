import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/coach/domain/coach_exception.dart';
import 'package:hayati_app/features/coach/domain/coach_persona.dart';
import 'package:hayati_app/features/coach/domain/coach_register.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_repository_provider.dart';
import 'package:hayati_app/features/coach/domain/coach_transcript_entry.dart';
import 'package:hayati_app/features/coach/domain/coach_window.dart';
import 'package:hayati_app/features/coach/presentation/state/coach_send_controller.dart';
import 'package:hayati_app/features/coach/presentation/state/coach_transcript.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

import '../../../../support/fake_coach_repository.dart';

void main() {
  const uid = 'user-1';
  const coupleId = 'couple-1';
  const persona = CoachPersonaId.coach;

  final controller = coachSendControllerProvider(uid, coupleId, persona);
  final transcript = coachTranscriptProvider(uid, coupleId, persona);

  ProviderContainer arrange(FakeCoachRepository repo) {
    final container = ProviderContainer(
      overrides: [coachRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('success appends exactly [user, response] and returns to idle', () async {
    final repo = FakeCoachRepository();
    final container = arrange(repo);
    container.listen(controller, (_, _) {});

    await container.read(controller.notifier).send(
      text: 'hi',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );

    expect(
      container.read(transcript).entries,
      const [CoachUserTurn('hi'), CoachPersonaTurn('Fixture coach reply.')],
    );
    expect(container.read(controller), isA<CoachSendIdle>());
  });

  test('a CoachException failure sets CoachSendFailure, transcript untouched', () async {
    final repo = FakeCoachRepository()
      ..onSendMessage = (_) async => throw const CoachUnavailableException();
    final container = arrange(repo);
    container.listen(controller, (_, _) {});

    await container.read(controller.notifier).send(
      text: 'hi',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );

    final state = container.read(controller);
    expect(state, isA<CoachSendFailure>());
    expect((state as CoachSendFailure).failure, isA<CoachUnavailableException>());
    expect(container.read(transcript).entries, isEmpty);
  });

  test('re-entrant sends are dropped while one is in flight (one repo call)', () async {
    final gate = Completer<CoachReply>();
    final repo = FakeCoachRepository()..onSendMessage = (_) => gate.future;
    final container = arrange(repo);
    container.listen(controller, (_, _) {});
    final notifier = container.read(controller.notifier);

    final first = notifier.send(
      text: 'a',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );
    final second = notifier.send(
      text: 'b',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );

    gate.complete(FakeCoachRepository.cannedReply);
    await first;
    await second;

    expect(repo.callLog, hasLength(1));
    expect(repo.callLog.single.messages.last.text, 'a');
  });

  test('the captured notifier lands the reply even if the controller is disposed mid-send', () async {
    final gate = Completer<CoachReply>();
    final repo = FakeCoachRepository()..onSendMessage = (_) => gate.future;
    final container = arrange(repo);
    final sub = container.listen(controller, (_, _) {});
    final notifier = container.read(controller.notifier);

    final sending = notifier.send(
      text: 'hi',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );
    // Simulate a mid-send persona switch tearing this autoDispose controller down.
    container.invalidate(controller);

    gate.complete(const CoachReply(kind: CoachReplyKind.reply, text: 'landed'));
    await sending;

    // The reply still landed in the persona's keepAlive transcript family.
    expect(
      container.read(transcript).entries,
      const [CoachUserTurn('hi'), CoachPersonaTurn('landed')],
    );
    sub.close();
  });

  test('the window passed to the repo matches buildCoachWindow output', () async {
    final repo = FakeCoachRepository();
    final container = arrange(repo);
    container.listen(controller, (_, _) {});
    final notifier = container.read(controller.notifier);

    await notifier.send(
      text: 'first',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );
    await notifier.send(
      text: 'second',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );

    expect(repo.callLog, hasLength(2));
    expect(
      repo.callLog[0].messages,
      buildCoachWindow(entries: const [], newUserText: 'first'),
    );
    expect(
      repo.callLog[1].messages,
      buildCoachWindow(
        entries: const [
          CoachUserTurn('first'),
          CoachPersonaTurn('Fixture coach reply.'),
        ],
        newUserText: 'second',
      ),
    );
    expect(repo.callLog[1].language, ContentLanguage.en);
    expect(repo.callLog[1].register, CoachRegister.enNeutral);
  });

  test('a persona-B send proceeds while persona-A is in flight', () async {
    final gateA = Completer<CoachReply>();
    final repo = FakeCoachRepository()
      ..onSendMessage = (call) => call.personaId == CoachPersonaId.coach
          ? gateA.future
          : Future<CoachReply>.value(FakeCoachRepository.cannedReply);
    final container = arrange(repo);
    final controllerA =
        coachSendControllerProvider(uid, coupleId, CoachPersonaId.coach);
    final controllerB =
        coachSendControllerProvider(uid, coupleId, CoachPersonaId.dateGenie);
    container.listen(controllerA, (_, _) {});
    container.listen(controllerB, (_, _) {});

    final aFuture = container.read(controllerA.notifier).send(
      text: 'a',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );
    // B proceeds to completion even though A is gated open.
    await container.read(controllerB.notifier).send(
      text: 'b',
      language: ContentLanguage.en,
      register: CoachRegister.enNeutral,
    );

    expect(container.read(controllerB), isA<CoachSendIdle>());
    expect(container.read(controllerA), isA<CoachSendSending>());
    expect(
      container
          .read(coachTranscriptProvider(uid, coupleId, CoachPersonaId.dateGenie))
          .entries,
      hasLength(2),
    );

    gateA.complete(FakeCoachRepository.cannedReply);
    await aFuture;
    expect(container.read(controllerA), isA<CoachSendIdle>());
  });
}
