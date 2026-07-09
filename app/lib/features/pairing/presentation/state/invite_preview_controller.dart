import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/invite_preview.dart';
import '../../domain/invite_preview_repository.dart';

part 'invite_preview_controller.g.dart';

/// Riverpod 3 auto-retry disabled (same rationale as `profileStreamProvider`):
/// a failed preview is a network blip or an off-contract response — neither
/// self-heals on a backoff timer, and silently re-hammering the endpoint just
/// pins the join screen on a spinner. Recovery is the user-driven
/// `ref.invalidate(invitePreviewProvider(code))` behind the error view.
Duration? _noRetry(int retryCount, Object error) => null;

/// Fetches the zero-auth [InvitePreviewResult] for [code] so the join screen
/// can show who invited the user before they sign in. A family keyed by code:
/// each code gets its own cached AsyncValue, so previewing a second code never
/// clobbers the first. autoDispose (screen-scoped) — the preview is released
/// when the screen stops watching it.
///
/// The three screen states fall straight out of the returned AsyncValue
/// (loading → data | error); an [InvitePreviewStatus.unknown]/expired RESULT is
/// still `AsyncData`, not an error (the code simply isn't joinable).
@Riverpod(retry: _noRetry)
Future<InvitePreviewResult> invitePreview(Ref ref, String code) =>
    ref.watch(invitePreviewRepositoryProvider).preview(code);
