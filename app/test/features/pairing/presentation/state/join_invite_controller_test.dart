import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/presentation/state/join_invite_controller.dart';

import '../../../../support/fake_invite_repository.dart';

void main() {
  (ProviderContainer, FakeInviteRepository) makeContainer() {
    final repo = FakeInviteRepository();
    final container = ProviderContainer(
      overrides: [inviteRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);
    return (container, repo);
  }

  JoinInviteController notifier(ProviderContainer container) =>
      container.read(joinInviteControllerProvider.notifier);

  // Keeps the autoDispose controller and its state alive across reads — a
  // stand-in for the screen that watches it (mirrors invite_share_controller).
  void keepAlive(ProviderContainer container) =>
      container.listen(joinInviteControllerProvider, (_, _) {});

  test('starts idle: data is null before any join', () {
    final (container, _) = makeContainer();
    keepAlive(container);

    final state = container.read(joinInviteControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value, isNull);
    expect(state.isLoading, isFalse);
  });

  test('a successful join exposes the coupleId as data', () async {
    final (container, repo) = makeContainer();
    keepAlive(container);

    await notifier(container).join('ABCD2345');

    final state = container.read(joinInviteControllerProvider);
    expect(state.value, repo.coupleId);
    expect(repo.joinedCodes, ['ABCD2345']);
    expect(repo.joinCalls, 1);
  });

  test(
    'a typed failure surfaces as an AsyncError carrying the exception',
    () async {
      final (container, repo) = makeContainer();
      keepAlive(container);
      repo.onJoinInvite = (_) async {
        throw const InviteJoinExpiredException(message: 'gone');
      };

      await notifier(container).join('ABCD2345');

      final state = container.read(joinInviteControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<InviteJoinExpiredException>());
    },
  );

  test('drops a re-entrant join while one is in flight', () async {
    final (container, repo) = makeContainer();
    keepAlive(container);
    final inFlight = Completer<String>();
    repo.onJoinInvite = (_) => inFlight.future;

    final controller = notifier(container);
    unawaited(controller.join('ABCD2345'));
    unawaited(controller.join('WXYZ6789')); // dropped by the guard
    await pumpEventQueue();

    expect(container.read(joinInviteControllerProvider).isLoading, isTrue);
    expect(repo.joinCalls, 1);
    expect(repo.joinedCodes, ['ABCD2345']);

    inFlight.complete('couple-1');
    await pumpEventQueue();

    // Guard released after completion: a later join goes through again.
    expect(container.read(joinInviteControllerProvider).value, 'couple-1');
    await controller.join('WXYZ6789');
    expect(repo.joinCalls, 2);
  });

  test('goes through loading before settling on data', () async {
    final (container, repo) = makeContainer();
    final inFlight = Completer<String>();
    repo.onJoinInvite = (_) => inFlight.future;

    final states = <bool>[];
    container.listen(
      joinInviteControllerProvider,
      (_, next) => states.add(next.isLoading),
      fireImmediately: true,
    );

    final future = notifier(container).join('ABCD2345');
    await pumpEventQueue();
    expect(container.read(joinInviteControllerProvider).isLoading, isTrue);

    inFlight.complete('couple-1');
    await future;

    // idle(false) → loading(true) → data(false)
    expect(states.first, isFalse);
    expect(states, contains(true));
    expect(states.last, isFalse);
  });
}
