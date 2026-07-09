import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/invite_repository_provider.dart';

part 'join_invite_controller.g.dart';

/// Drives the "redeem a code" action on the join screen. Its state is an
/// `AsyncValue<String?>` mapping the flow's four positions (same AsyncValue
/// idiom as `InviteShareController`, so the screen switches on it directly):
///
/// - idle    — `AsyncData(null)` (the initial [build]; nothing attempted yet).
/// - in-flight — `AsyncLoading` (a join is running).
/// - error   — `AsyncError` carrying the typed [InviteException] the UI speaks
///             to (unknown code, expired, consumed, self-join, already-paired,
///             profile-missing, or the generic network/permission/unknown).
/// - success — `AsyncData(coupleId)` with a non-null `couples/{coupleId}` id.
///
/// autoDispose (screen-scoped, like `InviteShareController`); navigation on
/// success is the UI stage's concern — this controller only exposes the id.
@Riverpod()
class JoinInviteController extends _$JoinInviteController {
  /// Single-flight guard: drops a re-entrant [join] while one is in flight
  /// (double-tap / double-submit debounce), mirroring `InviteShareController`.
  bool _joining = false;

  @override
  FutureOr<String?> build() => null;

  /// Redeems [code] for the signed-in caller, moving the state loading →
  /// data(coupleId) | error(InviteException). A no-op while a previous join is
  /// still in flight. [code] is expected pre-normalized by the caller
  /// (`normalizeInviteCode`); the server re-validates regardless.
  Future<void> join(String code) async {
    if (_joining) return;
    _joining = true;
    state = const AsyncValue.loading();
    try {
      final coupleId = await ref
          .read(inviteRepositoryProvider)
          .joinInvite(code);
      if (ref.mounted) state = AsyncValue.data(coupleId);
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncValue.error(error, stackTrace);
    } finally {
      if (ref.mounted) _joining = false;
    }
  }
}
