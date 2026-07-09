import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';
import 'package:hayati_app/features/pairing/presentation/state/invite_share_controller.dart';

import '../../../../support/fake_invite_repository.dart';
import '../../../../support/fake_invite_share_launcher.dart';

void main() {
  (ProviderContainer, FakeInviteRepository, FakeInviteShareLauncher)
  makeContainer() {
    final repo = FakeInviteRepository();
    final launcher = FakeInviteShareLauncher();
    final container = ProviderContainer(
      overrides: [
        inviteRepositoryProvider.overrideWith((ref) => repo),
        inviteShareLauncherProvider.overrideWith((ref) => launcher),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);
    addTearDown(launcher.dispose);
    return (container, repo, launcher);
  }

  // Keeps the autoDispose controller alive across reads/retry. Call AFTER the
  // repository's behaviour is arranged so the first build sees it.
  void keepAlive(ProviderContainer container) =>
      container.listen(inviteShareControllerProvider, (_, _) {});

  group('build', () {
    test('issues the invite exactly once', () async {
      final (container, repo, _) = makeContainer();
      keepAlive(container);

      final invite = await container.read(inviteShareControllerProvider.future);

      expect(invite, repo.invite);
      expect(repo.createCalls, 1);
    });

    test('a domain failure surfaces as an AsyncError', () async {
      final (container, repo, _) = makeContainer();
      repo.onCreateInvite = () async {
        throw const InviteNetworkException(message: 'offline');
      };
      keepAlive(container);

      await expectLater(
        container.read(inviteShareControllerProvider.future),
        throwsA(isA<InviteNetworkException>()),
      );
      expect(
        container.read(inviteShareControllerProvider).error,
        isA<InviteNetworkException>(),
      );
    });
  });

  group('retry', () {
    test('re-runs build, recovering from a failure', () async {
      final (container, repo, _) = makeContainer();
      repo.onCreateInvite = () async {
        throw const InviteNetworkException(message: 'offline');
      };
      keepAlive(container);

      await expectLater(
        container.read(inviteShareControllerProvider.future),
        throwsA(isA<InviteNetworkException>()),
      );

      repo.onCreateInvite = null; // next build succeeds
      container.read(inviteShareControllerProvider.notifier).retry();

      final invite = await container.read(inviteShareControllerProvider.future);
      expect(invite, repo.invite);
      expect(repo.createCalls, 2);
    });
  });

  group('share', () {
    test('delegates the composed message to the launcher', () async {
      final (container, _, launcher) = makeContainer();
      keepAlive(container);
      await container.read(inviteShareControllerProvider.future);

      await container
          .read(inviteShareControllerProvider.notifier)
          .share('join me: ABCD2345');

      expect(launcher.sharedMessages, ['join me: ABCD2345']);
    });

    test('drops a re-entrant share while one is in flight', () async {
      final (container, _, launcher) = makeContainer();
      keepAlive(container);
      await container.read(inviteShareControllerProvider.future);
      final notifier = container.read(inviteShareControllerProvider.notifier);

      final inFlight = Completer<void>();
      launcher.onShareText = (_) => inFlight.future;

      unawaited(notifier.share('first'));
      unawaited(notifier.share('second'));
      await pumpEventQueue();

      // The guard dropped 'second' — only the in-flight 'first' was launched.
      expect(launcher.sharedMessages, ['first']);

      inFlight.complete();
      await pumpEventQueue();

      // Guard released: a later share goes through again.
      await notifier.share('third');
      expect(launcher.sharedMessages, ['first', 'third']);
    });
  });
}
