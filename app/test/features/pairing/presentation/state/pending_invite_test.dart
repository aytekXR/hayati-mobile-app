import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/presentation/state/pending_invite.dart';

import '../../../../support/fake_deep_link_source.dart';

void main() {
  ProviderContainer makeContainer(FakeDeepLinkSource source) {
    final container = ProviderContainer(
      overrides: [deepLinkSourceProvider.overrideWith((ref) => source)],
    );
    addTearDown(container.dispose);
    addTearDown(source.dispose);
    return container;
  }

  // Keeps the keepAlive notifier warm and its stream subscription active.
  void keepAlive(ProviderContainer container) =>
      container.listen(pendingInviteProvider, (_, _) {});

  test('starts with no pending invite', () {
    final source = FakeDeepLinkSource();
    final container = makeContainer(source);
    keepAlive(container);

    expect(container.read(pendingInviteProvider), isNull);
  });

  test('a cold-start link lands the code in state', () async {
    final source = FakeDeepLinkSource(
      initialUri: Uri.parse('hayati://invite/ABCD2345'),
    );
    final container = makeContainer(source);
    keepAlive(container);

    // build() resolves the cold-start link asynchronously.
    expect(container.read(pendingInviteProvider), isNull);
    await pumpEventQueue();

    expect(container.read(pendingInviteProvider), 'ABCD2345');
  });

  test('a warm link updates the state', () async {
    final source = FakeDeepLinkSource();
    final container = makeContainer(source);
    keepAlive(container);
    await pumpEventQueue();
    expect(container.read(pendingInviteProvider), isNull);

    source.emit(Uri.parse('hayati://invite/WXYZ6789'));
    await pumpEventQueue();

    expect(container.read(pendingInviteProvider), 'WXYZ6789');
  });

  test('an invalid link leaves the state unchanged', () async {
    final source = FakeDeepLinkSource(
      initialUri: Uri.parse('https://example.com/foo'),
    );
    final container = makeContainer(source);
    keepAlive(container);
    await pumpEventQueue();
    expect(container.read(pendingInviteProvider), isNull);

    source.emit(Uri.parse('hayati://invite/badcode'));
    await pumpEventQueue();

    expect(container.read(pendingInviteProvider), isNull);
  });

  test('clear() drops a pending code once the join flow consumes it', () async {
    final source = FakeDeepLinkSource(
      initialUri: Uri.parse('hayati://invite/ABCD2345'),
    );
    final container = makeContainer(source);
    keepAlive(container);
    await pumpEventQueue();
    expect(container.read(pendingInviteProvider), 'ABCD2345');

    container.read(pendingInviteProvider.notifier).clear();

    expect(container.read(pendingInviteProvider), isNull);
  });

  test('clear() is idempotent when nothing is pending', () {
    final source = FakeDeepLinkSource();
    final container = makeContainer(source);
    keepAlive(container);

    container.read(pendingInviteProvider.notifier).clear();

    expect(container.read(pendingInviteProvider), isNull);
  });

  test(
    'the most recent valid code wins and an invalid one never clobbers it',
    () async {
      final source = FakeDeepLinkSource(
        initialUri: Uri.parse('hayati://invite/ABCD2345'),
      );
      final container = makeContainer(source);
      keepAlive(container);
      await pumpEventQueue();
      expect(container.read(pendingInviteProvider), 'ABCD2345');

      source.emit(Uri.parse('hayati://invite/WXYZ6789'));
      await pumpEventQueue();
      expect(container.read(pendingInviteProvider), 'WXYZ6789');

      // A later invalid link is ignored — the last valid code stays.
      source.emit(Uri.parse('hayati://invite/not-a-code'));
      await pumpEventQueue();
      expect(container.read(pendingInviteProvider), 'WXYZ6789');
    },
  );
}
