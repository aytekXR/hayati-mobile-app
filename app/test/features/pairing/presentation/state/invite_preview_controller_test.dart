import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/presentation/state/invite_preview_controller.dart';

import '../../../../support/fake_invite_preview_repository.dart';

void main() {
  (ProviderContainer, FakeInvitePreviewRepository) makeContainer() {
    final repo = FakeInvitePreviewRepository();
    final container = ProviderContainer(
      overrides: [invitePreviewRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);
    return (container, repo);
  }

  test('fetches the preview for the requested code', () async {
    final (container, repo) = makeContainer();

    final result = await container.read(
      invitePreviewProvider('ABCD2345').future,
    );

    expect(result, repo.result);
    expect(repo.previewedCodes, ['ABCD2345']);
  });

  test('an expired/unknown result surfaces as data, not an error', () async {
    final (container, repo) = makeContainer();
    repo.onPreview = (_) async =>
        const InvitePreviewResult(status: InvitePreviewStatus.expired);

    final result = await container.read(
      invitePreviewProvider('ABCD2345').future,
    );

    expect(result.status, InvitePreviewStatus.expired);
  });

  test('a repository failure surfaces as an AsyncError', () async {
    final (container, repo) = makeContainer();
    repo.onPreview = (_) async {
      throw const InviteNetworkException(message: 'offline');
    };

    await expectLater(
      container.read(invitePreviewProvider('ABCD2345').future),
      throwsA(isA<InviteNetworkException>()),
    );
    expect(
      container.read(invitePreviewProvider('ABCD2345')).error,
      isA<InviteNetworkException>(),
    );
  });

  test(
    'the family keys by code — a second code never clobbers the first',
    () async {
      final (container, repo) = makeContainer();
      repo.onPreview = (code) async => InvitePreviewResult(
        status: InvitePreviewStatus.valid,
        creatorDisplayName: 'creator-$code',
      );

      final first = await container.read(
        invitePreviewProvider('ABCD2345').future,
      );
      final second = await container.read(
        invitePreviewProvider('WXYZ6789').future,
      );

      expect(first.creatorDisplayName, 'creator-ABCD2345');
      expect(second.creatorDisplayName, 'creator-WXYZ6789');
    },
  );

  test('invalidate re-fetches (user-driven retry after a failure)', () async {
    final (container, repo) = makeContainer();
    repo.onPreview = (_) async {
      throw const InviteNetworkException(message: 'offline');
    };
    // Keep the family entry alive so invalidate re-runs it.
    container.listen(invitePreviewProvider('ABCD2345'), (_, _) {});

    await expectLater(
      container.read(invitePreviewProvider('ABCD2345').future),
      throwsA(isA<InviteNetworkException>()),
    );

    repo.onPreview = null; // next fetch succeeds
    container.invalidate(invitePreviewProvider('ABCD2345'));

    final result = await container.read(
      invitePreviewProvider('ABCD2345').future,
    );
    expect(result, repo.result);
    expect(repo.previewCalls, 2);
  });
}
