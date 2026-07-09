import 'package:app_links/app_links.dart';

import '../domain/deep_link_source.dart';

/// [DeepLinkSource] backed by the app_links plugin: [getInitialLink] for the
/// cold-start URL and [uriLinkStream] for warm links (app_links 7.x API).
class AppLinksDeepLinkSource implements DeepLinkSource {
  AppLinksDeepLinkSource([AppLinks? appLinks])
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> initialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> uriStream() => _appLinks.uriLinkStream;
}
