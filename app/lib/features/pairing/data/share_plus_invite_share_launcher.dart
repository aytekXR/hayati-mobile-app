import 'package:share_plus/share_plus.dart';

import '../domain/invite_share_launcher.dart';

/// [InviteShareLauncher] over share_plus's `SharePlus.instance.share`. Thin by
/// design: it just wraps the text in [ShareParams] and drops the
/// [ShareResult] — the invite is fire-and-forget from the app's side (the pair
/// completes on the invitee's device, M2.3).
class SharePlusInviteShareLauncher implements InviteShareLauncher {
  const SharePlusInviteShareLauncher();

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
