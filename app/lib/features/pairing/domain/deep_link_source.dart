import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deep_link_source.g.dart';

/// Seam over the platform deep-link plugin (app_links). The concrete adapter
/// drives a platform channel (which throws in the plain test VM), so the
/// pending-invite state depends on this interface and tests substitute a fake
/// — no method channel is ever hit under `flutter test`.
abstract interface class DeepLinkSource {
  /// The URL that cold-started the app, if it was launched from a `hayati://`
  /// link; null on a normal launch. Resolved once, at startup.
  Future<Uri?> initialLink();

  /// URLs delivered while the app is already running (a warm link tapped while
  /// Hayati is foregrounded or backgrounded).
  Stream<Uri> uriStream();
}

/// Provides the app's [DeepLinkSource].
///
/// Deliberately unimplemented at the base (same contract as
/// `inviteRepositoryProvider`): the flavor entrypoints override it with the
/// app_links-backed adapter, and tests override it per container with a fake.
@Riverpod(keepAlive: true)
DeepLinkSource deepLinkSource(Ref ref) => throw StateError(
  'deepLinkSourceProvider must be overridden at bootstrap '
  '(main_dev.dart / main_prod.dart) or per test container.',
);
