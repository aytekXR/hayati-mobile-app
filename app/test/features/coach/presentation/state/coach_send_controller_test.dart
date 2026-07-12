import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
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

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_coach_repository.dart';

void main() {
  const uid = 'user-1';
  const coupleId = 'couple-1';
  const persona = CoachPersonaId.coach;

  final controller = coachSendControllerProvider(uid, coupleId, persona);
  final transcript = coachTranscriptProvider(uid, coupleId, persona);

  /// The transcript's owner guard (ADR-017 D3) reads the live auth state, so
  /// every container composes the auth seam — signed in as the owner. The fake
  /// is returned alongside so a test can drive a mid-send sign-out.
  (ProviderContainer, FakeAuthRepository) arrangeWithAuth(
    FakeCoachRepository repo,
  ) {
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: uid, displayName: 'Test'),
    );
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [
        coachRepositoryProvider.overrideWith((ref) => repo),
        authRepositoryProvider.overrideWith((ref) => auth),
      ],
    );
    addTearDown(container.dispose);
    return (container, auth);
  }

  ProviderContainer arrange(FakeCoachRepository repo) =>
      arrangeWithAuth(repo).$1;

  test(
    'success appends exactly [user, response] and returns to idle',
    () async {
      final repo = FakeCoachRepository();
      final container = arrange(repo);
      container.listen(controller, (_, _) {});

      await container
          .read(controller.notifier)
          .send(
            text: 'hi',
            language: ContentLanguage.en,
            register: CoachRegister.enNeutral,
          );

      expect(container.read(transcript).entries, const [
        CoachUserTurn('hi'),
        CoachPersonaTurn('Fixture coach reply.'),
      ]);
      expect(container.read(controller), isA<CoachSendIdle>());
    },
  );

  test(
    'a CoachException failure sets CoachSendFailure, transcript untouched',
    () async {
      final repo = FakeCoachRepository()
        ..onSendMessage = (_) async => throw const CoachUnavailableException();
      final container = arrange(repo);
      container.listen(controller, (_, _) {});

      await container
          .read(controller.notifier)
          .send(
            text: 'hi',
            language: ContentLanguage.en,
            register: CoachRegister.enNeutral,
          );

      final state = container.read(controller);
      expect(state, isA<CoachSendFailure>());
      expect(
        (state as CoachSendFailure).failure,
        isA<CoachUnavailableException>(),
      );
      expect(container.read(transcript).entries, isEmpty);
    },
  );

  test(
    're-entrant sends are dropped while one is in flight (one repo call)',
    () async {
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
    },
  );

  test(
    'the captured notifier lands the reply even if the controller is disposed mid-send',
    () async {
      final gate = Completer<CoachReply>();
      final repo = FakeCoachRepository()..onSendMessage = (_) => gate.future;
      final container = arrange(repo);
      final sub = container.listen(controller, (_, _) {});
      // Keep the keepAlive transcript observable (family, so it outlives the
      // controller regardless — the listener just mirrors real UI wiring).
      container.listen(transcript, (_, _) {});
      final notifier = container.read(controller.notifier);

      final sending = notifier.send(
        text: 'hi',
        language: ContentLanguage.en,
        register: CoachRegister.enNeutral,
      );
      // A mid-send persona switch drops the LAST listener of this autoDispose
      // controller, so it is GENUINELY disposed — not merely refreshed (S019
      // review find: `container.invalidate` on a still-listened element only
      // schedules a rebuild, keeping `ref.mounted` true, which left the
      // capture-before-await rule unexercised). The dispose is scheduled on a
      // macrotask; the real awaits below let it run before the reply lands.
      sub.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // Proof of genuine teardown: a fresh read rebuilds a NEW notifier instance.
      expect(identical(container.read(controller.notifier), notifier), isFalse);

      gate.complete(
        const CoachReply(kind: CoachReplyKind.reply, text: 'landed'),
      );
      await sending;

      // The reply still landed in the persona's keepAlive transcript family,
      // through the reference captured BEFORE the await — a post-await
      // `ref.read` on the disposed controller would have thrown instead.
      expect(container.read(transcript).entries, const [
        CoachUserTurn('hi'),
        CoachPersonaTurn('landed'),
      ]);
    },
  );

  test(
    'a sign-out landing mid-send drops the late reply — the wiped transcript stays empty',
    () async {
      // ADR-017 D3 + the S019 review's confirmed SERIOUS find: the root
      // listener's family invalidation is LAZY on a keepAlive element, so
      // without the owner guard the in-flight exchange would re-populate the
      // just-wiped conversation (crisis text included) and survive into the
      // next same-uid sign-in. The guard drops a late exchange whose owner is
      // no longer the signed-in user.
      final gate = Completer<CoachReply>();
      final repo = FakeCoachRepository()..onSendMessage = (_) => gate.future;
      final (container, auth) = arrangeWithAuth(repo);
      container.listen(controller, (_, _) {});
      final notifier = container.read(controller.notifier);

      final sending = notifier.send(
        text: 'a heavy message',
        language: ContentLanguage.en,
        register: CoachRegister.enNeutral,
      );

      // Remote sign-out mid-send: the auth stream flips, and the app root's
      // listener wipes the family (mirrored here exactly as app.dart does it).
      auth.emit(null);
      await Future<void>.delayed(Duration.zero);
      container.invalidate(coachTranscriptProvider);

      gate.complete(const CoachReply(kind: CoachReplyKind.reply, text: 'late'));
      await sending;

      // The late exchange was DROPPED: nothing re-populated the conversation.
      expect(container.read(transcript).entries, isEmpty);
    },
  );

  test(
    'the window passed to the repo matches buildCoachWindow output',
    () async {
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
    },
  );

  test('a persona-B send proceeds while persona-A is in flight', () async {
    final gateA = Completer<CoachReply>();
    final repo = FakeCoachRepository()
      ..onSendMessage = (call) => call.personaId == CoachPersonaId.coach
          ? gateA.future
          : Future<CoachReply>.value(FakeCoachRepository.cannedReply);
    final container = arrange(repo);
    final controllerA = coachSendControllerProvider(
      uid,
      coupleId,
      CoachPersonaId.coach,
    );
    final controllerB = coachSendControllerProvider(
      uid,
      coupleId,
      CoachPersonaId.dateGenie,
    );
    container.listen(controllerA, (_, _) {});
    container.listen(controllerB, (_, _) {});

    final aFuture = container
        .read(controllerA.notifier)
        .send(
          text: 'a',
          language: ContentLanguage.en,
          register: CoachRegister.enNeutral,
        );
    // B proceeds to completion even though A is gated open.
    await container
        .read(controllerB.notifier)
        .send(
          text: 'b',
          language: ContentLanguage.en,
          register: CoachRegister.enNeutral,
        );

    expect(container.read(controllerB), isA<CoachSendIdle>());
    expect(container.read(controllerA), isA<CoachSendSending>());
    expect(
      container
          .read(
            coachTranscriptProvider(uid, coupleId, CoachPersonaId.dateGenie),
          )
          .entries,
      hasLength(2),
    );

    gateA.complete(FakeCoachRepository.cannedReply);
    await aFuture;
    expect(container.read(controllerA), isA<CoachSendIdle>());
  });
}
