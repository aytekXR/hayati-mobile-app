import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/deep_link_source.dart';
import '../../domain/invite_deep_link.dart';

part 'pending_invite.g.dart';

/// The invite code captured from a `hayati://invite/<code>` deep link, or null
/// when none is pending. keepAlive + activated from the app root (app.dart) so
/// a cold-start link — delivered before any pairing screen mounts — is caught
/// and held, not dropped. State only this session: the join flow (M2.3)
/// consumes the code from here.
///
/// [build] subscribes to warm links and, in parallel, resolves the cold-start
/// link (same stream-in-build + `ref.onDispose` discipline as `AuthController`).
/// Every URL runs through [inviteCodeFromUri]; a valid code replaces the state
/// (last wins) and an invalid one is ignored.
@Riverpod(keepAlive: true)
class PendingInvite extends _$PendingInvite {
  @override
  String? build() {
    final source = ref.watch(deepLinkSourceProvider);
    final subscription = source.uriStream().listen(_onUri);
    ref.onDispose(subscription.cancel);
    unawaited(_consumeInitialLink(source));
    return null;
  }

  Future<void> _consumeInitialLink(DeepLinkSource source) async {
    final uri = await source.initialLink();
    if (!ref.mounted || uri == null) return;
    _onUri(uri);
  }

  void _onUri(Uri uri) {
    final code = inviteCodeFromUri(uri);
    if (code != null) state = code;
  }

  /// Drops the pending code once the join flow has consumed it (a successful
  /// join, or the user dismissing the prompt) so a returning session is not
  /// re-offered a code it already acted on. Idempotent — clearing when already
  /// null is a no-op.
  void clear() => state = null;
}
