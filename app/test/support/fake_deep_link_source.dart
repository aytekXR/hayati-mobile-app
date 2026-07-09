import 'dart:async';

import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';

/// Hand-written fake for the deep-link seam, in the same behaviour-knob style
/// as [FakeInviteRepository]: [initialUri] seeds the cold-start link resolved
/// by [initialLink], and [emit] pushes warm links through the broadcast stream
/// returned by [uriStream] — so `PendingInvite` can be driven without a method
/// channel.
class FakeDeepLinkSource implements DeepLinkSource {
  FakeDeepLinkSource({this.initialUri});

  /// The URL [initialLink] resolves to; null models a normal (non-link) launch.
  Uri? initialUri;

  final StreamController<Uri> _uris = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => initialUri;

  @override
  Stream<Uri> uriStream() => _uris.stream;

  /// Delivers a warm link to subscribers of [uriStream].
  void emit(Uri uri) => _uris.add(uri);

  Future<void> dispose() => _uris.close();
}
