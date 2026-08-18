import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/analytics.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/state/analytics_funnel_sync.dart';
import 'package:hayati_app/features/profile/presentation/state/profile_providers.dart';

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_local_flag_store.dart';
import '../../../../support/fake_profile_repository.dart';
import '../../../../support/recording_analytics_sink.dart';

/// The three funnel events that are STATE TRANSITIONS rather than user actions
/// — `install`, `signup`, `paired` (ADR-057 D4).
///
/// Added in review pass 2. Its absence was a real gap: the sentinel proves a
/// call site EXISTS for these three, and the emitter unit tests prove the
/// once-keys work, but nothing proved this provider *fires them on the right
/// state* — which is where `paired` lives, and `paired` is half of Gate 2.
void main() {
  late RecordingAnalyticsSink sink;
  late FakeLocalFlagStore flags;

  setUp(() {
    sink = RecordingAnalyticsSink();
    flags = FakeLocalFlagStore();
  });

  const uid = 'uid-1';
  const user = AuthUser(uid: uid, displayName: 'Test');

  RelationshipProfile profile({String? coupleId}) => RelationshipProfile(
    status: RelationshipStatus.married,
    contentLanguage: ContentLanguage.tr,
    register: ContentRegister.playful,
    coupleId: coupleId,
  );

  ProviderContainer arrange({
    AuthUser? initialUser,
    RelationshipProfile? initialProfile,
    bool wireAuth = true,
  }) {
    final auth = FakeAuthRepository(initialUser: initialUser);
    addTearDown(auth.dispose);
    final profiles = FakeProfileRepository(
      initialProfiles: initialProfile == null ? null : {uid: initialProfile},
    );
    final container = ProviderContainer(
      overrides: [
        analyticsSinkProvider.overrideWithValue(sink),
        localFlagStoreProvider.overrideWithValue(flags),
        if (wireAuth) authRepositoryProvider.overrideWith((ref) => auth),
        profileRepositoryProvider.overrideWith((ref) => profiles),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Mirrors `HayatiApp.build`'s `ref.listen(analyticsFunnelSyncProvider, ...)`
  /// exactly. The listener is load-bearing, not decoration: a keepAlive
  /// provider with NO listener recomputes only lazily on the next read, so a
  /// bare `read` here would model a different app from the one that ships.
  void activate(ProviderContainer container) {
    final sub = container.listen(analyticsFunnelSyncProvider, (_, _) {});
    addTearDown(sub.close);
  }

  test('signed out: install fires, and nothing else does', () {
    final container = arrange();
    activate(container);
    expect(sink.names, ['install']);
  });

  test(
    'signed in without a profile: install and signup, but NOT paired',
    () async {
      final container = arrange(initialUser: user);
      container.read(analyticsFunnelSyncProvider);
      await Future<void>.delayed(Duration.zero);
      container.read(analyticsFunnelSyncProvider);
      expect(sink.names, ['install', 'signup']);
    },
  );

  test(
    'signed in with a profile that has no coupleId: still no paired',
    () async {
      final container = arrange(initialUser: user, initialProfile: profile());
      container.read(analyticsFunnelSyncProvider);
      await Future<void>.delayed(Duration.zero);
      container.read(analyticsFunnelSyncProvider);
      expect(sink.names, ['install', 'signup']);
    },
  );

  test('a profile carrying a coupleId emits paired — for EITHER partner, '
      'because the profile is stamped for both', () async {
    final container = arrange(
      initialUser: user,
      initialProfile: profile(coupleId: 'couple-1'),
    );
    activate(container);
    // Await the stream's FIRST VALUE rather than pumping an arbitrary number
    // of microtasks: "delay until it passes" is a test that will start failing
    // on a slower machine for reasons that have nothing to do with the code.
    await container.read(profileStreamProvider(uid).future);
    await Future<void>.delayed(Duration.zero);
    expect(sink.names, ['install', 'signup', 'paired']);
  });

  test('re-reading the provider does not re-emit anything', () async {
    final container = arrange(
      initialUser: user,
      initialProfile: profile(coupleId: 'couple-1'),
    );
    activate(container);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
      container.invalidate(analyticsFunnelSyncProvider);
    }
    await Future<void>.delayed(Duration.zero);
    expect(sink.names, ['install', 'signup', 'paired']);
  });

  test('an UNWIRED auth seam still emits install — the funnel degrades, the '
      'app does not (ADR-039 D1)', () {
    // authRepositoryProvider throws when unoverridden. This provider is
    // activated from HayatiApp.build, so an unguarded throw would take every
    // widget test that does not wire auth down at build time.
    final container = arrange(wireAuth: false);
    expect(() => container.read(analyticsFunnelSyncProvider), returnsNormally);
    expect(sink.names, ['install']);
  });
}
