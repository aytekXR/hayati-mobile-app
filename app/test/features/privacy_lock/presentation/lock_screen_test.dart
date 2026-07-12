import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/l10n/gen/app_localizations.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/privacy_lock/presentation/lock_screen.dart';
import 'package:hayati_app/features/privacy_lock/presentation/widgets/pin_keypad.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes
// it — the seam every other widget test uses.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_pin_lock_store.dart';
import '../../../support/localized_app.dart';
import '../../../support/pin_lock_fixtures.dart';

/// `LockScreen` in isolation — the copy, the pad, the accelerator, the recovery
/// panel. What the lock actually HIDES is proven against the whole app in
/// `privacy_guard_test.dart`; this file is about what the screen SAYS, which on
/// a DV surface is its own kind of correctness.
final _now = DateTime.utc(2026, 7, 10, 9);
final _nowMs = _now.millisecondsSinceEpoch;

/// The three cooldown tiers and the string each MUST render (review finding
/// DVUX-5: one shared "about a minute" would understate the 5-minute tier 5×).
final _tiers = <String, (Duration, String Function(AppLocalizations))>{
  '30 seconds': (
    const Duration(seconds: 30),
    (l10n) => l10n.lockCooldownThirtySeconds,
  ),
  'a minute': (
    const Duration(minutes: 1),
    (l10n) => l10n.lockCooldownOneMinute,
  ),
  '5 minutes': (
    const Duration(minutes: 5),
    (l10n) => l10n.lockCooldownFiveMinutes,
  ),
};

void main() {
  /// The mutable wall clock behind the cooldown countdown. Reset per test.
  late DateTime clock;

  setUp(() => clock = _now);

  List<Override> arrange({
    required PinLockRecord record,
    FakeBiometricAuthenticator? biometrics,
  }) {
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: 'uid-1', displayName: 'Aytek'),
    );
    addTearDown(auth.dispose);
    return [
      pinLockStoreProvider.overrideWithValue(FakePinLockStore(initial: record)),
      initialLockSnapshotProvider.overrideWithValue(
        PinLockSnapshot(record: record),
      ),
      biometricAuthenticatorProvider.overrideWithValue(
        biometrics ?? FakeBiometricAuthenticator(available: false),
      ),
      authRepositoryProvider.overrideWith((ref) => auth),
      soloClockProvider.overrideWith(
        (ref) =>
            () => clock,
      ),
    ];
  }

  Future<void> pumpLock(
    WidgetTester tester, {
    required PinLockRecord record,
    Locale locale = const Locale('en'),
    FakeBiometricAuthenticator? biometrics,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        const LockScreen(),
        locale: locale,
        overrides: arrange(record: record, biometrics: biometrics),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool padEnabled(WidgetTester tester) =>
      tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled;

  group('PIN entry', () {
    testWidgets(
      'a wrong PIN clears the dots and says how many tries are left',
      (tester) async {
        final en = l10nFor(const Locale('en'));
        await pumpLock(tester, record: lockRecord());

        await enterPin(tester, kWrongPin);

        // One wrong of the four free attempts → three left before a wait.
        expect(find.text(en.lockWrongPin(3)), findsOneWidget);
        // The dots are cleared: the attempt leaves nothing on screen.
        expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 0);
      },
    );

    testWidgets('the correct PIN produces no error copy', (tester) async {
      final en = l10nFor(const Locale('en'));
      await pumpLock(tester, record: lockRecord());

      await enterPin(tester, kTestPin);

      // "Accepted" has nothing honest to say — in the real app the gate simply
      // un-mounts this screen on the next frame.
      expect(find.text(en.lockWrongPin(3)), findsNothing);
      expect(find.text(en.lockCooldownThirtySeconds), findsNothing);
    });
  });

  group('cooldown copy is TIER-ACCURATE (review finding DVUX-5)', () {
    for (final tier in _tiers.entries) {
      testWidgets('${tier.key} left → that exact string, pad disabled', (
        tester,
      ) async {
        final en = l10nFor(const Locale('en'));
        final (remaining, copy) = tier.value;
        await pumpLock(
          tester,
          record: lockRecord(
            wrongCount: 5,
            lockoutUntilMs: _nowMs + remaining.inMilliseconds,
          ),
        );

        expect(find.text(copy(en)), findsOneWidget);
        // And NEITHER of the other two — an under-stated wait is the over-claim
        // DVUX-5 exists to prevent.
        for (final other in _tiers.values) {
          if (other.$2 == copy) continue;
          expect(find.text(other.$2(en)), findsNothing);
        }
        expect(padEnabled(tester), isFalse);
      });
    }

    testWidgets('the pad re-enables itself when the deadline elapses — no '
        'keypress needed', (tester) async {
      final en = l10nFor(const Locale('en'));
      await pumpLock(
        tester,
        record: lockRecord(
          wrongCount: 5,
          lockoutUntilMs: _nowMs + const Duration(seconds: 30).inMilliseconds,
        ),
      );
      expect(padEnabled(tester), isFalse);
      expect(find.text(en.lockCooldownThirtySeconds), findsOneWidget);

      // The wall clock moves past the deadline; the screen's own 1s ticker is
      // what notices — the user is not required to tap to find out.
      clock = _now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));

      expect(padEnabled(tester), isTrue);
      expect(find.text(en.lockCooldownThirtySeconds), findsNothing);
    });

    testWidgets('a 5-minute cooldown still reads honestly as it counts down', (
      tester,
    ) async {
      final en = l10nFor(const Locale('en'));
      await pumpLock(
        tester,
        record: lockRecord(
          wrongCount: 7,
          lockoutUntilMs: _nowMs + const Duration(minutes: 5).inMilliseconds,
        ),
      );
      expect(find.text(en.lockCooldownFiveMinutes), findsOneWidget);

      // 4m20s in: 40s of wait left. The copy rounds UP to the smallest tier that
      // still covers the remaining wait, so it can never understate it.
      clock = _now.add(const Duration(minutes: 4, seconds: 20));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(en.lockCooldownOneMinute), findsOneWidget);
      expect(padEnabled(tester), isFalse);
    });
  });

  group('the biometric accelerator', () {
    testWidgets('is offered when the record enables it AND it is available', (
      tester,
    ) async {
      final en = l10nFor(const Locale('en'));
      await pumpLock(
        tester,
        record: lockRecord(biometricEnabled: true, enrollment: 'enrollment-v1'),
        biometrics: FakeBiometricAuthenticator(enrollment: 'enrollment-v1'),
      );
      expect(find.text(en.lockBiometricCta), findsOneWidget);
    });

    testWidgets('is not offered when the record has it off', (tester) async {
      final en = l10nFor(const Locale('en'));
      await pumpLock(
        tester,
        record: lockRecord(),
        biometrics: FakeBiometricAuthenticator(),
      );
      expect(find.text(en.lockBiometricCta), findsNothing);
    });

    testWidgets(
      'an enrollment CHANGE auto-revokes it and shows the honest one-liner',
      (tester) async {
        final en = l10nFor(const Locale('en'));
        // The record captured 'enrollment-v1' at enable time; a partner has
        // since added their face, so the platform now reports something else.
        // The accelerator is revoked BEFORE it can be offered (ADR-018 D1).
        await pumpLock(
          tester,
          record: lockRecord(
            biometricEnabled: true,
            enrollment: 'enrollment-v1',
          ),
          biometrics: FakeBiometricAuthenticator(enrollment: 'enrollment-v2'),
        );

        expect(find.text(en.lockBiometricRevoked), findsOneWidget);
        expect(find.text(en.lockBiometricCta), findsNothing);
        // The PIN still works: the ACCELERATOR was revoked, not the credential.
        expect(padEnabled(tester), isTrue);
      },
    );

    testWidgets('tapping it prompts with the localized reason', (tester) async {
      final en = l10nFor(const Locale('en'));
      final biometrics = FakeBiometricAuthenticator(
        enrollment: 'enrollment-v1',
      );
      await pumpLock(
        tester,
        record: lockRecord(biometricEnabled: true, enrollment: 'enrollment-v1'),
        biometrics: biometrics,
      );

      await tester.tap(find.text(en.lockBiometricCta));
      await tester.pumpAndSettle();

      expect(
        biometrics.callLog,
        contains('authenticate:${en.lockBiometricReason}'),
      );
    });

    testWidgets(
      'a biometric FAILURE consumes no attempt and starts no cooldown',
      (tester) async {
        final en = l10nFor(const Locale('en'));
        await pumpLock(
          tester,
          record: lockRecord(
            biometricEnabled: true,
            enrollment: 'enrollment-v1',
          ),
          biometrics: FakeBiometricAuthenticator(
            enrollment: 'enrollment-v1',
            succeeds: false,
          ),
        );

        await tester.tap(find.text(en.lockBiometricCta));
        await tester.pumpAndSettle();

        // Silent fall-back to the keypad: a cancelled Face ID prompt is not a
        // wrong PIN, and treating it as one would hand a partner a way to burn
        // the user's attempts (ADR-018 D1).
        expect(padEnabled(tester), isTrue);
        expect(find.text(en.lockWrongPin(3)), findsNothing);
        expect(find.text(en.lockCooldownThirtySeconds), findsNothing);
      },
    );
  });

  group('the keypad is pinned LTR in every locale (review finding DVUX-6)', () {
    for (final locale in supportedTestLocales) {
      testWidgets('${locale.languageCode}: the digit row reads 1-2-3', (
        tester,
      ) async {
        await pumpLock(tester, record: lockRecord(), locale: locale);

        // Numeric pads are NOT mirrored in RTL on any platform (iOS's own AR
        // passcode pad reads 1-2-3 left-to-right). The surrounding copy flips;
        // the pad must not. The AR/RTL golden pins the same thing visually.
        final one = tester.getCenter(find.text('1')).dx;
        final two = tester.getCenter(find.text('2')).dx;
        final three = tester.getCenter(find.text('3')).dx;
        expect(one, lessThan(two));
        expect(two, lessThan(three));
      });
    }
  });

  group('the recovery panel is a WIDGET, never a dialog', () {
    testWidgets('it opens with NO Navigator anywhere above the lock screen', (
      tester,
    ) async {
      final en = l10nFor(const Locale('en'));
      await pumpLock(tester, record: lockRecord());

      await tester.tap(find.text(en.lockForgotPin));
      await tester.pumpAndSettle();

      // The keypad column was SWAPPED for the confirm panel — not covered by a
      // route. In the real app this screen sits above the only Navigator and has
      // no Overlay ancestor at all (ADR-018 D3; review findings SEC-7/FLUTTER-1):
      // a showDialog here would THROW, and on the recovery path that crash IS
      // the lockout.
      expect(find.text(en.lockRecoveryTitle), findsOneWidget);
      expect(find.text(en.lockRecoveryBody), findsOneWidget);
      expect(find.byType(PinKeypad), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
