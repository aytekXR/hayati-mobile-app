import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/app.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/core/l10n/gen/app_localizations.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';
import 'package:hayati_app/features/coach/domain/coach_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answers_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_assignment.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/couple_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/question.dart';
import 'package:hayati_app/features/daily_question/domain/question_pack_repository_provider.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_screen.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/legal/domain/legal_version.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/pairing/domain/invite_preview_repository.dart';
import 'package:hayati_app/features/pairing/presentation/partner_preview_screen.dart';
import 'package:hayati_app/features/pairing/presentation/state/pending_invite.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/privacy_lock/presentation/lock_screen.dart';
import 'package:hayati_app/features/privacy_lock/presentation/privacy_guard.dart';
import 'package:hayati_app/features/privacy_lock/presentation/privacy_shield_cover.dart';
import 'package:hayati_app/features/privacy_lock/presentation/state/privacy_lock_controller.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/onboarding_gate.dart';
import 'package:hayati_app/features/settings/domain/app_icon_switcher.dart';
import 'package:hayati_app/features/settings/presentation/settings_screen.dart';

import '../../../support/fake_app_icon_switcher.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_coach_repository.dart';
import '../../../support/fake_couple_answers_repository.dart';
import '../../../support/fake_couple_day_repository.dart';
import '../../../support/fake_couple_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/fake_invite_preview_repository.dart';
import '../../../support/fake_local_flag_store.dart';
import '../../../support/fake_pin_lock_store.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/fake_purchases_repository.dart';
import '../../../support/fake_question_pack_repository.dart';
import '../../../support/localized_app.dart';
import '../../../support/pin_lock_fixtures.dart';

/// THE BYPASS SUITE — the M6 accept line (ADR-018 test commitments).
///
/// Every case boots the REAL app (`HayatiApp` + overrides), because the claim
/// under test is structural: the gate mounts in `MaterialApp.builder`, above
/// `home` AND every pushed route, so nothing can route around it. A widget-level
/// test of `LockScreen` in isolation would prove none of that.
///
/// EVERY `findsNothing`-while-locked assertion is paired with an unlock→reveal
/// POSITIVE CONTROL (review finding TEST-3): `findsNothing` over an `Offstage`
/// subtree passes even if the content never rendered at all, so a bare negative
/// proves nothing. Each negative here is followed by "…and the correct PIN
/// reveals exactly that content", which fails loudly if the content was never
/// there.
///
/// Hit-testability is asserted separately from findability ([expectHitTestable]
/// / [expectNotHitTestable]): a paint-over cover would satisfy the first and
/// fail the second, and the difference IS the bypass.
const _uid = 'uid-1';
const _coupleId = 'couple-1';
const _partnerUid = 'uid-2';
const _user = AuthUser(uid: _uid, displayName: 'Aytek');

/// UTC+3 permanently; 09:00 UTC → 12:00 Istanbul on 2026-07-10.
const _istanbul = 'Europe/Istanbul';
final _fixedNow = DateTime.utc(2026, 7, 10, 9);
const _todayKey = '20260710';

const _packId = 'paired_en';

/// The one string that IS couple content on the paired home. If the gate leaks,
/// this is what leaks.
const _question = 'EN paired question 1';

const _pairedPack = QuestionPack(
  packId: _packId,
  version: 3,
  language: ContentLanguage.en,
  register: QuestionRegister.respectful,
  questions: [
    Question(
      id: 'paired_en_001',
      category: QuestionCategory.deep,
      depth: 3,
      text: _question,
    ),
  ],
);

const _assignment = CoupleDayAssignment(
  questionId: 'paired_en_001',
  packId: _packId,
  packVersion: 3,
);

// ADR-023: consented so the guarded flow routes to the home, not the gate.
const _pairedProfile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.en,
  register: ContentRegister.respectful,
  coupleId: _coupleId,
  consent: Consent(version: currentLegalVersion),
);

const _soloProfile = RelationshipProfile(
  status: RelationshipStatus.dating,
  contentLanguage: ContentLanguage.en,
  register: ContentRegister.respectful,
  consent: Consent(version: currentLegalVersion),
);

/// Is [finder]'s render box actually reachable by a pointer at its own centre?
///
/// This is the assertion a paint-over cover would fail: `Offstage` drops the
/// subtree from hit-testing entirely (ADR-018 Decision 3), so a locked app's
/// content cannot be tapped THROUGH the overlay — not merely "is hidden behind"
/// it.
bool _hitTestable(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final centre = box.localToGlobal(box.size.center(Offset.zero));
  final result = tester.hitTestOnBinding(centre);
  return result.path.any((entry) => identical(entry.target, box));
}

void expectNotHitTestable(WidgetTester tester, Finder finder) => expect(
  _hitTestable(tester, finder),
  isFalse,
  reason: 'the gated subtree must not be hit-testable while locked',
);

void expectHitTestable(WidgetTester tester, Finder finder) => expect(
  _hitTestable(tester, finder),
  isTrue,
  reason: 'the reveal control: the same content must be tappable once unlocked',
);

/// Settles the app, giving the gated subtree its async hops too.
///
/// A property of `TickerMode(enabled: false)` worth knowing before reading the
/// assertions below — it is STRONGER than what ADR-018 Decision 3 claims, and it
/// is not an accident of this harness:
///
/// **Riverpod 3's `ConsumerWidget` PAUSES every provider subscription it holds
/// when `TickerMode.of(context)` is false** (`flutter_riverpod`'s
/// `src/core/consumer.dart`: "To optimize performance by avoiding unnecessary
/// network requests and pausing unused streams, Consumer will temporarily stop
/// listening to providers when the widget stops being visible"). So while the
/// lock is up, the gated subtree does not merely stop PAINTING couple content —
/// it stops FETCHING it: the profile / couple / day / answer streams beneath the
/// overlay are paused, and they resume, state intact, on unlock. The bypass
/// story only improves; the tests simply have to be honest that content under
/// the lock is UN-RENDERED rather than rendered-and-hidden — so every negative
/// here leans on its unlock→reveal control (review finding TEST-3), not on
/// `skipOffstage`.
///
/// Providers mounted ABOVE the gate stay live, deliberately: `HayatiApp` itself
/// watches `pendingInviteProvider`, which is why a deep link arriving while
/// locked is still CAPTURED (asserted below).
///
/// `pumpAndSettle` alone can also return early here: with no ticker beneath the
/// gate nothing keeps scheduling frames (that is the point — it is also what
/// stops `pumpAndSettle` hanging on a spinner behind the lock), so the pumps
/// below give the un-paused parts of the tree their microtask hops.
Future<void> settleGated(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var hop = 0; hop < 10; hop++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(const Locale('en'));

  /// Boots the whole app with a signed-in, PAIRED user (so there is real couple
  /// content to hide) and whatever lock snapshot the case needs.
  Future<
    ({
      FakeAuthRepository auth,
      FakePinLockStore store,
      FakeDeepLinkSource deepLinks,
      ProviderContainer container,
    })
  >
  pumpApp(
    WidgetTester tester, {
    PinLockSnapshot snapshot = noLockSnapshot,
    PinLockRecord? stored,
    RelationshipProfile profile = _pairedProfile,
    Uri? deepLink,
    DateTime Function()? clock,
    FakeBiometricAuthenticator? biometrics,
    bool signedIn = true,
  }) async {
    // `signedIn: false` with a stored record is the ORPHANED-RECORD edge
    // (ADR-018 D1/D8): a lock that outlived its session, e.g. because the
    // sign-out wipe's `clear()` threw. The lock screen still comes up — the
    // overlay is state-driven, not auth-driven — and recovery must still escape.
    final auth = FakeAuthRepository(initialUser: signedIn ? _user : null);
    final deepLinks = FakeDeepLinkSource(initialUri: deepLink);
    final profiles = FakeProfileRepository(initialProfiles: {_uid: profile});
    final couples = FakeCoupleRepository(
      initialCouples: {
        _coupleId: const Couple(
          id: _coupleId,
          memberUids: [_uid, _partnerUid],
          timezone: _istanbul,
        ),
      },
    );
    final days = FakeCoupleDayRepository(
      initialDays: {
        FakeCoupleDayRepository.keyFor(_coupleId, _todayKey): _assignment,
      },
    );
    final answers = FakeCoupleAnswersRepository();
    final packs = FakeQuestionPackRepository()..seedPack(_pairedPack);
    final mirrors = FakeEntitlementRepository();
    final store = FakePinLockStore(initial: stored ?? snapshot.record);
    addTearDown(auth.dispose);
    addTearDown(deepLinks.dispose);
    addTearDown(profiles.dispose);
    addTearDown(couples.dispose);
    addTearDown(days.dispose);
    addTearDown(answers.dispose);
    addTearDown(mirrors.dispose);

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(flavor: AppFlavor.dev),
        ),
        authRepositoryProvider.overrideWith((ref) => auth),
        deepLinkSourceProvider.overrideWith((ref) => deepLinks),
        profileRepositoryProvider.overrideWith((ref) => profiles),
        coupleRepositoryProvider.overrideWith((ref) => couples),
        coupleDayRepositoryProvider.overrideWith((ref) => days),
        coupleAnswersRepositoryProvider.overrideWith((ref) => answers),
        questionPackRepositoryProvider.overrideWith((ref) => packs),
        entitlementRepositoryProvider.overrideWith((ref) => mirrors),
        purchasesRepositoryProvider.overrideWith(
          (ref) => FakePurchasesRepository(),
        ),
        invitePreviewRepositoryProvider.overrideWith(
          (ref) => FakeInvitePreviewRepository(),
        ),
        localFlagStoreProvider.overrideWithValue(FakeLocalFlagStore()),
        coachRepositoryProvider.overrideWith((ref) => FakeCoachRepository()),
        soloClockProvider.overrideWith((ref) => clock ?? () => _fixedNow),
        // The four device-privacy seams the entrypoints bind by value.
        pinLockStoreProvider.overrideWithValue(store),
        initialLockSnapshotProvider.overrideWithValue(snapshot),
        biometricAuthenticatorProvider.overrideWithValue(
          biometrics ?? FakeBiometricAuthenticator(available: false),
        ),
        appIconSwitcherProvider.overrideWithValue(
          FakeAppIconSwitcher(supported: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HayatiApp()),
    );
    await settleGated(tester);
    return (
      auth: auth,
      store: store,
      deepLinks: deepLinks,
      container: container,
    );
  }

  /// Drives the app to the background, the way iOS actually sequences it
  /// (`resumed → inactive → hidden → paused`; the framework's
  /// `AppLifecycleListener` asserts on invalid transitions).
  Future<void> background(WidgetTester tester) async {
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
  }

  /// …and back: `paused → hidden → inactive → resumed`.
  Future<void> foreground(WidgetTester tester) async {
    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await settleGated(tester);
  }

  group('cold start', () {
    testWidgets(
      'lock enabled → lock screen up, home content neither findable nor '
      'hit-testable — and the correct PIN reveals THAT SAME content',
      (tester) async {
        await pumpApp(tester, snapshot: lockedSnapshot());

        // The overlay is up.
        expect(find.byType(LockScreen), findsOneWidget);
        expect(find.text(en.lockPrompt), findsOneWidget);

        // The app subtree is MOUNTED and keeps every bit of its state — but it
        // is not painted, not hit-testable, and (see the note on
        // [settleGated]) its provider subscriptions are PAUSED, so the couple
        // content is not even fetched while the lock is up.
        expect(find.byType(OnboardingGate, skipOffstage: false), findsOne);
        expect(find.text(_question), findsNothing);
        expectNotHitTestable(
          tester,
          find.byType(OnboardingGate, skipOffstage: false),
        );

        // THE POSITIVE CONTROL (review finding TEST-3): the same string, after
        // the correct PIN. Without this, the findsNothing above would pass even
        // if the paired home had never rendered at all.
        await enterPin(tester, kTestPin);

        expect(find.byType(LockScreen), findsNothing);
        expect(find.byType(PairedHomeScreen), findsOneWidget);
        expect(find.text(_question), findsOneWidget);
        expectHitTestable(tester, find.text(_question));
      },
    );

    testWidgets('no lock record → no lock UI anywhere; the home is untouched', (
      tester,
    ) async {
      await pumpApp(tester, snapshot: noLockSnapshot);

      // The free-tier / never-set-up claim, asserted rather than assumed.
      expect(find.byType(LockScreen), findsNothing);
      expect(find.byType(PrivacyShieldCover), findsNothing);
      expect(find.text(_question), findsOneWidget);
      expectHitTestable(tester, find.text(_question));

      // And the gate is not even holding the subtree offstage.
      final offstage = tester.widget<Offstage>(
        find
            .descendant(
              of: find.byType(PrivacyGuard),
              matching: find.byType(Offstage),
            )
            .first,
      );
      expect(offstage.offstage, isFalse);
    });
  });

  group('background return', () {
    testWidgets('past the grace window → re-locked', (tester) async {
      var now = _fixedNow;
      await pumpApp(tester, snapshot: lockedSnapshot(), clock: () => now);
      await enterPin(tester, kTestPin);
      expect(find.text(_question), findsOneWidget);

      await background(tester);
      // 61s away: past the 60s grace.
      now = _fixedNow.add(const Duration(seconds: 61));
      await foreground(tester);

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text(_question), findsNothing);
      expectNotHitTestable(
        tester,
        find.byType(OnboardingGate, skipOffstage: false),
      );

      // Reveal control: the SAME content comes back — and the Navigator/state
      // beneath was kept, not rebuilt from scratch.
      await enterPin(tester, kTestPin);
      expect(find.text(_question), findsOneWidget);
    });

    testWidgets('within the grace window → NOT re-locked', (tester) async {
      var now = _fixedNow;
      await pumpApp(tester, snapshot: lockedSnapshot(), clock: () => now);
      await enterPin(tester, kTestPin);

      await background(tester);
      // 59s: the Messages-and-back flow the window is sized for.
      now = _fixedNow.add(const Duration(seconds: 59));
      await foreground(tester);

      expect(find.byType(LockScreen), findsNothing);
      expect(find.text(_question), findsOneWidget);
    });

    testWidgets(
      'inactive ALONE raises the shield but does NOT start the grace clock',
      (tester) async {
        var now = _fixedNow;
        await pumpApp(tester, snapshot: lockedSnapshot(), clock: () => now);
        await enterPin(tester, kTestPin);

        // The share sheet / permission dialog / biometric prompt path: the user
        // never left the app.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(find.byType(PrivacyShieldCover), findsOneWidget);

        // Ten minutes later — far past the grace window — coming back must NOT
        // re-lock: `.inactive` never stamped a backgroundedAt. Locking here
        // would fight the very biometric prompt that unlocks us.
        now = _fixedNow.add(const Duration(minutes: 10));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await settleGated(tester);

        expect(find.byType(PrivacyShieldCover), findsNothing);
        expect(find.byType(LockScreen), findsNothing);
        expect(find.text(_question), findsOneWidget);
      },
    );
  });

  group('the shield', () {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      testWidgets('${state.name} → the full-bleed cover is on top', (
        tester,
      ) async {
        // Universal, free tier included (Decision 5): no lock record here.
        await pumpApp(tester, snapshot: noLockSnapshot);
        expect(find.byType(PrivacyShieldCover), findsNothing);

        // Walk the real transition chain up to the state under test.
        for (final step in const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(step);
          await tester.pump();
          if (step == state) break;
        }

        expect(find.byType(PrivacyShieldCover), findsOneWidget);
        // Full-bleed is the point (review finding FLUTTER-4): content painted
        // AROUND a content-sized cover is exactly what the OS snapshots.
        final cover = tester.getRect(find.byType(PrivacyShieldCover));
        expect(cover, tester.getRect(find.byType(PrivacyGuard)));
        // And it is ON TOP: the app content underneath cannot be hit.
        expectNotHitTestable(tester, find.text(_question, skipOffstage: false));

        await foreground(tester);
        expect(find.byType(PrivacyShieldCover), findsNothing);
        expectHitTestable(tester, find.text(_question));
      });
    }
  });

  group('cold-start deep link', () {
    testWidgets(
      'the invite code is CAPTURED while locked, the preview screen is not '
      'findable or hit-testable — and renders on unlock',
      (tester) async {
        final app = await pumpApp(
          tester,
          snapshot: lockedSnapshot(),
          // Unpaired: the gate routes an invited, onboarded user to the preview.
          profile: _soloProfile,
          deepLink: Uri.parse('hayati://invite/ABCD2345'),
        );

        expect(find.byType(LockScreen), findsOneWidget);

        // State, not navigation (Decision 3): the code lands in the provider
        // even behind the lock — nothing is dropped.
        expect(app.container.read(pendingInviteProvider), 'ABCD2345');

        // …and nothing renders it: the preview is neither findable nor
        // reachable while the overlay is up.
        expect(find.byType(PartnerPreviewScreen), findsNothing);
        expect(
          find.byType(PartnerPreviewScreen, skipOffstage: false),
          findsNothing,
        );
        expectNotHitTestable(
          tester,
          find.byType(OnboardingGate, skipOffstage: false),
        );

        await enterPin(tester, kTestPin);

        expect(find.byType(PartnerPreviewScreen), findsOneWidget);
        expectHitTestable(tester, find.byType(PartnerPreviewScreen));
      },
    );
  });

  group('pushed routes', () {
    testWidgets(
      'a pushed route is covered by a re-lock and survives it on the Navigator',
      (tester) async {
        var now = _fixedNow;
        await pumpApp(tester, snapshot: lockedSnapshot(), clock: () => now);
        await enterPin(tester, kTestPin);

        // Push settings through the gear the homes now carry.
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Away and back, past grace.
        await background(tester);
        now = _fixedNow.add(const Duration(seconds: 61));
        await foreground(tester);

        // The gate is above the Navigator, so the PUSHED route is gated too.
        expect(find.byType(LockScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.text(en.settingsLockTitle), findsNothing);
        // Still on the Navigator (Offstage keeps the stack) — just unreachable.
        expect(find.byType(SettingsScreen, skipOffstage: false), findsOne);
        expectNotHitTestable(
          tester,
          find.byType(SettingsScreen, skipOffstage: false),
        );

        await enterPin(tester, kTestPin);

        // Offstage keeps the Navigator: the route is STILL on the stack.
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text(en.settingsLockTitle), findsOneWidget);
      },
    );
  });

  group('recovery — sign out FIRST, never drop the lock on hope', () {
    testWidgets(
      'confirm → sign-out succeeds → wiped + sign-in screen, with NO frame of '
      'home content in between',
      (tester) async {
        final app = await pumpApp(tester, snapshot: lockedSnapshot());
        expect(app.store.record, isNotNull);

        await tester.tap(find.text(en.lockForgotPin));
        await tester.pumpAndSettle();
        expect(find.text(en.lockRecoveryTitle), findsOneWidget);

        await tester.tap(find.text(en.lockRecoveryConfirm));

        // Frame by frame to the settled state: the overlay must never come down
        // onto painted couple content. (The old wipe-then-sign-out ordering did
        // exactly that when sign-out threw — review finding DVUX-3.)
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump();
          expect(
            find.text(_question),
            findsNothing,
            reason:
                'couple content became visible during recovery (frame '
                '$frame)',
          );
        }
        await tester.pumpAndSettle();

        // Signed out, record wiped, overlay gone — in that order.
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(find.byType(LockScreen), findsNothing);
        expect(app.store.record, isNull);
        expect(app.store.callLog, contains('clear'));
        expect(
          app.container.read(privacyLockControllerProvider),
          const PrivacyLockDisabled(),
        );
      },
    );

    testWidgets(
      'sign-out THROWS → still locked, honest retry copy, record INTACT',
      (tester) async {
        final app = await pumpApp(tester, snapshot: lockedSnapshot());
        app.auth.onSignOut = () async =>
            throw const AuthNetworkException(message: 'offline');

        await tester.tap(find.text(en.lockForgotPin));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.lockRecoveryConfirm));
        await tester.pumpAndSettle();

        // Nothing was wiped, because nothing was confirmed (Decision 4).
        expect(find.byType(LockScreen), findsOneWidget);
        expect(find.text(en.lockRecoveryFailed), findsOneWidget);
        expect(app.store.record, isNotNull);
        expect(app.store.callLog, isNot(contains('clear')));
        expect(
          app.container.read(privacyLockControllerProvider),
          isA<PrivacyLocked>(),
        );
        // And the couple content it is holding closed stayed closed.
        expect(find.text(_question), findsNothing);
      },
    );

    testWidgets('cancel returns to the keypad with nothing touched', (
      tester,
    ) async {
      final app = await pumpApp(tester, snapshot: lockedSnapshot());

      await tester.tap(find.text(en.lockForgotPin));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.lockRecoveryCancel));
      await tester.pumpAndSettle();

      expect(find.text(en.lockRecoveryTitle), findsNothing);
      expect(find.text(en.lockPrompt), findsOneWidget);
      expect(app.store.record, isNotNull);
      expect(app.auth.signOutCalls, 0);
    });

    testWidgets(
      'the ORPHANED-RECORD edge: recovery escapes even when the app is ALREADY '
      'signed out — the one path that could brick the device permanently',
      (tester) async {
        // A lock record that outlived its session (ADR-018 D1/D8 — e.g. the
        // sign-out wipe's `clear()` threw). ADR-018 D4 promises recovery here is
        // "idempotent and works when already signed out: it wipes and lands on
        // the sign-in screen either way."
        //
        // The trap this pins: the wipe used to ride ONLY the root
        // `ref.listen(authControllerProvider)`, which fires on a state CHANGE.
        // `AuthSignedOut` is value-equal, so signing out when ALREADY signed out
        // re-enters an identical state, Riverpod suppresses the notification, the
        // listener never runs — and the record is never wiped. The overlay would
        // stay up forever, showing NO error, with no escape: reinstalling does not
        // clear the Keychain (that is D2's whole point). A permanent brick.
        final app = await pumpApp(
          tester,
          snapshot: lockedSnapshot(),
          signedIn: false,
        );
        expect(app.store.record, isNotNull);
        expect(find.byType(LockScreen), findsOneWidget);

        await tester.tap(find.text(en.lockForgotPin));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.lockRecoveryConfirm));
        await tester.pumpAndSettle();

        expect(
          app.store.record,
          isNull,
          reason: 'the record MUST be wiped — otherwise the device is bricked',
        );
        expect(
          app.container.read(privacyLockControllerProvider),
          const PrivacyLockDisabled(),
        );
        expect(find.byType(LockScreen), findsNothing);
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(
          find.text(en.lockRecoveryFailed),
          findsNothing,
          reason: 'it did not fail — it must not claim it did',
        );
      },
    );
  });

  group('focus (review finding LOCKBYPASS-4)', () {
    testWidgets(
      'engaging the gate DROPS focus — an offstage TextField must not keep the '
      'keyboard up over the lock screen',
      (tester) async {
        // `Offstage` stops paint, hit-testing and semantics — but it does NOT
        // move focus. A composer the user was typing an answer into stays focused
        // underneath the lock, so iOS keeps the soft keyboard up OVER the lock
        // screen (covering the keypad's lower rows AND the always-visible
        // Forgot-PIN escape), and a hardware keyboard keeps talking to couple
        // content the lock is supposed to have closed. Unfocusing severs it.
        var now = _fixedNow;
        final store = FakePinLockStore();
        final container = ProviderContainer(
          overrides: [
            pinLockStoreProvider.overrideWithValue(store),
            initialLockSnapshotProvider.overrideWithValue(noLockSnapshot),
            biometricAuthenticatorProvider.overrideWithValue(
              FakeBiometricAuthenticator(available: false),
            ),
            authRepositoryProvider.overrideWith(
              (ref) => FakeAuthRepository(initialUser: _user),
            ),
            soloClockProvider.overrideWith(
              (ref) =>
                  () => now,
            ),
          ],
        );
        addTearDown(container.dispose);

        final field = FocusNode();
        addTearDown(field.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PrivacyGuard(
                child: Scaffold(
                  body: TextField(focusNode: field, autofocus: true),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(field.hasFocus, isTrue, reason: 'the composer is focused');

        // The real path: a PIN exists, the user leaves, and comes back past the
        // grace window.
        final controller = container.read(
          privacyLockControllerProvider.notifier,
        );
        await controller.enableLock('123456');
        controller.noteBackgrounded();
        now = _fixedNow.add(kLockGraceWindow + const Duration(seconds: 1));
        await controller.noteResumed();
        await tester.pumpAndSettle();

        expect(find.byType(LockScreen), findsOneWidget);
        expect(
          field.hasFocus,
          isFalse,
          reason:
              'focus must not survive the gate — the keyboard would ride up over '
              'the lock screen and keep typing into couple content',
        );
      },
    );
  });
}
