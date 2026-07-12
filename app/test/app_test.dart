import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/app.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';
import 'package:hayati_app/features/coach/domain/coach_persona.dart';
import 'package:hayati_app/features/coach/domain/coach_reply.dart';
import 'package:hayati_app/features/coach/presentation/state/coach_transcript.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_deep_link_source.dart';
import 'support/fake_profile_repository.dart';

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
}
