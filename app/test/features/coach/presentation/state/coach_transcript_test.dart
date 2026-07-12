import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/coach/domain/coach_persona.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/domain/coach_transcript_entry.dart';
import 'package:hayati_app/features/coach/presentation/state/coach_transcript.dart';

import '../../../../support/fake_auth_repository.dart';

void main() {
  const uid = 'user-1';
  const coupleId = 'couple-1';
  const persona = CoachPersonaId.coach;

  final provider = coachTranscriptProvider(uid, coupleId, persona);

  /// The transcript's owner guard (ADR-017 D3, the S019 review's mid-send
  /// sign-out find) reads the live auth state, so every container composes the
  /// auth seam — signed in as the transcript's owner by default.
  ProviderContainer arrange({FakeAuthRepository? auth}) {
    final fakeAuth =
        auth ??
        FakeAuthRepository(
          initialUser: const AuthUser(uid: uid, displayName: 'Test'),
        );
    if (auth == null) addTearDown(fakeAuth.dispose);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) => fakeAuth)],
    );
    addTearDown(container.dispose);
    container.listen(provider, (_, _) {});
    return container;
  }

  CoachTranscript notifierOf(ProviderContainer container) =>
      container.read(provider.notifier);

  CoachTranscriptState stateOf(ProviderContainer container) =>
      container.read(provider);

  test('initial state is empty, unlatched, hint-less', () {
    final container = arrange();

    final state = stateOf(container);
    expect(state.entries, isEmpty);
    expect(state.helpSticky, isFalse);
    expect(state.lastRemaining, isNull);
  });

  test('applyExchange on a reply appends [user, persona]', () {
    final container = arrange();

    notifierOf(container).applyExchange(
      userText: 'hi',
      reply: const CoachReply(kind: CoachReplyKind.reply, text: 'hey'),
    );

    final state = stateOf(container);
    expect(state.entries, const [CoachUserTurn('hi'), CoachPersonaTurn('hey')]);
    expect(state.helpSticky, isFalse);
  });

  test(
    'applyExchange on a help (pre-scan shape) appends [user, help] + latches',
    () {
      final container = arrange();

      notifierOf(container).applyExchange(
        userText: 'dark thought',
        reply: const CoachReply(
          kind: CoachReplyKind.help,
          text: 'please reach out',
          category: CoachCrisisCategory.selfHarm,
        ),
      );

      final state = stateOf(container);
      expect(state.entries, const [
        CoachUserTurn('dark thought'),
        CoachHelpTurn(
          'please reach out',
          category: CoachCrisisCategory.selfHarm,
        ),
      ]);
      expect(state.helpSticky, isTrue);
      expect(state.lastRemaining, isNull);
    },
  );

  test(
    'applyExchange on a help (post-filter shape) latches AND takes the hint',
    () {
      final container = arrange();

      notifierOf(container).applyExchange(
        userText: 'x',
        reply: const CoachReply(
          kind: CoachReplyKind.help,
          text: 'please reach out',
          category: CoachCrisisCategory.violence,
          remaining: CoachRemaining(daily: 5, monthly: 100),
        ),
      );

      final state = stateOf(container);
      expect(state.helpSticky, isTrue);
      expect(state.lastRemaining, const CoachRemaining(daily: 5, monthly: 100));
    },
  );

  test('the latch never un-sets on a later reply (defensive)', () {
    final container = arrange();
    final notifier = notifierOf(container);

    notifier.applyExchange(
      userText: 'crisis',
      reply: const CoachReply(kind: CoachReplyKind.help, text: 'help'),
    );
    notifier.applyExchange(
      userText: 'again',
      reply: const CoachReply(kind: CoachReplyKind.reply, text: 'ordinary'),
    );

    expect(stateOf(container).helpSticky, isTrue);
  });

  test('lastRemaining updates only when the reply carries it', () {
    final container = arrange();
    final notifier = notifierOf(container);

    notifier.applyExchange(
      userText: 'a',
      reply: const CoachReply(
        kind: CoachReplyKind.reply,
        text: 'r1',
        remaining: CoachRemaining(daily: 10, monthly: 500),
      ),
    );
    expect(
      stateOf(container).lastRemaining,
      const CoachRemaining(daily: 10, monthly: 500),
    );

    // A hint-less response (e.g. pre-scan help) leaves the prior value intact.
    notifier.applyExchange(
      userText: 'b',
      reply: const CoachReply(kind: CoachReplyKind.help, text: 'help'),
    );
    expect(
      stateOf(container).lastRemaining,
      const CoachRemaining(daily: 10, monthly: 500),
    );
  });

  test('reset clears entries, latch, and hint', () {
    final container = arrange();
    final notifier = notifierOf(container);

    notifier.applyExchange(
      userText: 'x',
      reply: const CoachReply(
        kind: CoachReplyKind.help,
        text: 'help',
        remaining: CoachRemaining(daily: 1, monthly: 2),
      ),
    );

    notifier.reset();

    final state = stateOf(container);
    expect(state.entries, isEmpty);
    expect(state.helpSticky, isFalse);
    expect(state.lastRemaining, isNull);
  });

  test('family isolation — other persona and other uid keys stay fresh', () {
    final container = arrange();
    notifierOf(container).applyExchange(
      userText: 'hi',
      reply: const CoachReply(kind: CoachReplyKind.reply, text: 'hey'),
    );

    final otherPersona = container.read(
      coachTranscriptProvider(uid, coupleId, CoachPersonaId.dateGenie),
    );
    final otherUid = container.read(
      coachTranscriptProvider('user-2', coupleId, persona),
    );

    expect(otherPersona.entries, isEmpty);
    expect(otherUid.entries, isEmpty);
    // The original key still holds its exchange.
    expect(stateOf(container).entries, hasLength(2));
  });
}
