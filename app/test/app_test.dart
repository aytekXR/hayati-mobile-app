import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/app.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_state.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';
import 'package:hayati_app/features/auth/presentation/state/auth_controller.dart';
import 'package:hayati_app/features/coach/domain/coach_persona.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/presentation/state/coach_transcript.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import 'support/fake_auth_repository.dart';
import 'support/fake_biometric_authenticator.dart';
import 'support/fake_data_rights_repository.dart';
import 'support/fake_deep_link_source.dart';
import 'support/fake_pin_lock_store.dart';
import 'support/fake_profile_repository.dart';
import 'support/pin_lock_fixtures.dart';

/// The device-privacy seams (ADR-018) that `HayatiApp` now mounts unconditionally
/// through the builder-level `PrivacyGuard`. Every full-app boot must bind them,
/// exactly as the flavor entrypoints do — they are deliberately unimplemented at
/// the base so a missing binding fails loudly instead of reaching a real
/// Keychain. The empty snapshot is the lock-never-set-up default: no lock UI, no
/// behaviour change (asserted in privacy_guard_test.dart).
List<Override> lockSeams() => [
  pinLockStoreProvider.overrideWithValue(FakePinLockStore()),
  initialLockSnapshotProvider.overrideWithValue(
    const PinLockSnapshot(record: null),
  ),
];

void main() {
  Future<void> pumpFlavor(WidgetTester tester, AppFlavor flavor) async {
    final fake = FakeAuthRepository();
    // The signed-out SignInScreen now watches pendingInviteProvider →
    // deepLinkSourceProvider (which the entrypoints override with the real
    // app_links adapter); compose the same seam with a fake instead.
    final deepLinks = FakeDeepLinkSource();
    addTearDown(fake.dispose);
    addTearDown(deepLinks.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig(flavor: flavor)),
          // Widget tests compose the same seam the entrypoints use
          // (runHayati extraOverrides) with a fake instead of Firebase.
          authRepositoryProvider.overrideWith((ref) => fake),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
          ...lockSeams(),
        ],
        child: const HayatiApp(),
      ),
    );
  }

  group('HayatiApp', () {
    testWidgets('boots into the auth shell with the dev flavor', (
      tester,
    ) async {
      await pumpFlavor(tester, AppFlavor.dev);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(kBrandName), findsOneWidget);
    });

    testWidgets('boots into the auth shell with the prod flavor', (
      tester,
    ) async {
      await pumpFlavor(tester, AppFlavor.prod);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(kBrandName), findsOneWidget);
    });

    // ADR-017 Decision 3: the coach transcript family is keepAlive (survives
    // route pops by design), so the always-mounted app root must tear it down
    // on any transition away from a signed-in user — otherwise a
    // sign-out → sign-in cycle in one process would resurrect the prior
    // conversation and leave crisis text reachable. This pins the retention-zero
    // claim: after sign-out the family is fresh, not merely off-screen.
    testWidgets('sign-out invalidates the whole coach transcript family', (
      tester,
    ) async {
      const uid = 'uid-1';
      const coupleId = 'couple-1';
      final auth = FakeAuthRepository(
        initialUser: const AuthUser(uid: uid, displayName: 'Aytek'),
      );
      final deepLinks = FakeDeepLinkSource();
      final profiles = FakeProfileRepository();
      addTearDown(auth.dispose);
      addTearDown(deepLinks.dispose);
      addTearDown(profiles.dispose);

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: AppFlavor.dev),
          ),
          authRepositoryProvider.overrideWith((ref) => auth),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
          // A null profile routes the signed-in gate to the self-contained
          // capture screen (no couple/solo repos needed for this test).
          profileRepositoryProvider.overrideWith((ref) => profiles),
          ...lockSeams(),
        ],
      );
      addTearDown(container.dispose);

      // Seed a conversation for the signed-in user.
      container
          .read(
            coachTranscriptProvider(
              uid,
              coupleId,
              CoachPersonaId.coach,
            ).notifier,
          )
          .applyExchange(
            userText: 'A message.',
            reply: const CoachReply(
              kind: CoachReplyKind.reply,
              text: 'A reply.',
            ),
          );
      expect(
        container
            .read(coachTranscriptProvider(uid, coupleId, CoachPersonaId.coach))
            .entries,
        isNotEmpty,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HayatiApp(),
        ),
      );
      await tester.pump();

      // A remote sign-out through the fake repo → the root listener invalidates.
      auth.emit(null);
      await tester.pump();

      // The family is fresh, not merely off-screen: a re-read rebuilds the
      // const initial state with zero entries.
      expect(
        container
            .read(coachTranscriptProvider(uid, coupleId, CoachPersonaId.coach))
            .entries,
        isEmpty,
      );
    });
  });

  // ADR-019 D7 — the root listener is the sole success-path wipe carrier for
  // account deletion, tested through the REAL app.dart wiring. These are the
  // mutation-check anchors: commenting the root listener's `wipe()` call makes
  // the success test's `store.record` assertion go red; the AuthError test is the
  // negative pair (protection stays, never wiped on error).
  group('account deletion + the root lock wipe (ADR-019 D7)', () {
    ({
      ProviderContainer container,
      FakeAuthRepository auth,
      FakeDataRightsRepository dataRights,
      FakePinLockStore store,
    })
    deleteHarness() {
      final auth = FakeAuthRepository(
        initialUser: const AuthUser(uid: 'uid-1', displayName: 'Aytek'),
      );
      final deepLinks = FakeDeepLinkSource();
      final profiles = FakeProfileRepository();
      final dataRights = FakeDataRightsRepository();
      final store = FakePinLockStore(initial: lockRecord());
      addTearDown(auth.dispose);
      addTearDown(deepLinks.dispose);
      addTearDown(profiles.dispose);

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: AppFlavor.dev),
          ),
          authRepositoryProvider.overrideWith((ref) => auth),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
          profileRepositoryProvider.overrideWith((ref) => profiles),
          dataRightsRepositoryProvider.overrideWith((ref) => dataRights),
          pinLockStoreProvider.overrideWithValue(store),
          initialLockSnapshotProvider.overrideWithValue(
            PinLockSnapshot(record: lockRecord()),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(available: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      return (
        container: container,
        auth: auth,
        dataRights: dataRights,
        store: store,
      );
    }

    testWidgets(
      'a successful deletion lands AuthSignedOut and the root listener WIPES '
      'the Keychain lock record',
      (tester) async {
        final env = deleteHarness();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: env.container,
            child: const HayatiApp(),
          ),
        );
        await tester.pump();
        expect(env.store.record, isNotNull);

        await env.container
            .read(authControllerProvider.notifier)
            .deleteAccount();
        // Flush the listener callback then the wipe's awaited store.clear().
        await tester.pump();
        await tester.pump();

        expect(
          env.container.read(authControllerProvider),
          const AuthSignedOut(),
        );
        expect(
          env.store.record,
          isNull,
          reason:
              'the root listener must wipe the Keychain lock record on '
              'AuthSignedOut (MUTATION-CHECK anchor)',
        );
      },
    );

    testWidgets(
      'a phase-2 sign-out throw leaves AuthError and the lock record INTACT '
      '(protection stays; the negative pair)',
      (tester) async {
        final env = deleteHarness();
        env.auth.onSignOutAfterAccountDeletion = () async =>
            throw const AuthUnknownException(code: 'internal-error');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: env.container,
            child: const HayatiApp(),
          ),
        );
        await tester.pump();

        await env.container
            .read(authControllerProvider.notifier)
            .deleteAccount();
        await tester.pump();
        await tester.pump();

        expect(env.container.read(authControllerProvider), isA<AuthError>());
        expect(
          env.store.record,
          isNotNull,
          reason: 'the lock is never wiped on AuthError — protection stays',
        );
      },
    );
  });
}
