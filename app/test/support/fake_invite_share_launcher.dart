import 'package:hayati_app/features/pairing/domain/invite_share_launcher.dart';

/// Hand-written fake for the share seam: records every message handed to
/// [shareText] (so widget tests assert the composed WhatsApp text without a
/// method channel) and exposes an [onShareText] hook to simulate a slow or
/// failing share sheet.
class FakeInviteShareLauncher implements InviteShareLauncher {
  /// Every message passed to [shareText], in order — the re-entrance guard is
  /// proven by asserting on its length.
  final List<String> sharedMessages = [];

  /// Behaviour override for the next [shareText] calls (e.g. a never-completing
  /// future to hold the share in flight); default records and returns.
  Future<void> Function(String text)? onShareText;

  @override
  Future<void> shareText(String text) {
    sharedMessages.add(text);
    final handler = onShareText;
    if (handler != null) return handler(text);
    return Future<void>.value();
  }

  Future<void> dispose() async {}
}
