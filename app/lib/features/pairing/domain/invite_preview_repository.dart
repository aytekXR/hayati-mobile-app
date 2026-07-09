import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'invite_exception.dart';
import 'invite_preview.dart';

part 'invite_preview_repository.g.dart';

/// Contract for the zero-auth invite preview (`invitePreview`, M2.2): fetches
/// the coarse [InvitePreviewResult] for a code so the join screen can show who
/// invited the user before they sign in. Distinct from [InviteRepository]
/// because the preview is a plain unauthenticated HTTP GET, not a callable.
///
/// Implementations map transport failures into the [InviteException] taxonomy
/// (network vs. unknown); a [InvitePreviewStatus.unknown] RESULT (code not
/// found) is a successful preview, never an exception. Anything else escaping
/// is a bug.
abstract interface class InvitePreviewRepository {
  Future<InvitePreviewResult> preview(String code);
}

/// Provides the app's [InvitePreviewRepository].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// http-backed implementation, and tests override it per container with a fake.
/// Use `overrideWith((ref) => …)` — the repository is constructed per
/// container, not a shared value.
@Riverpod(keepAlive: true)
InvitePreviewRepository invitePreviewRepository(Ref ref) => throw StateError(
  'invitePreviewRepositoryProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
