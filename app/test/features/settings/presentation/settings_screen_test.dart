import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_exception.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/data_rights/presentation/delete_account_screen.dart';
import 'package:hayati_app/features/data_rights/presentation/export_screen.dart';
import 'package:hayati_app/features/legal/presentation/legal_screen.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/privacy_lock/domain/pin_hasher.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/settings/domain/app_icon_switcher.dart';
import 'package:hayati_app/features/settings/presentation/pin_setup_screen.dart';
import 'package:hayati_app/features/settings/presentation/settings_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_app_icon_switcher.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_data_rights_repository.dart';
import '../../../support/fake_pin_lock_store.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/localized_app.dart';
import '../../../support/pin_lock_fixtures.dart';

/// The settings surface (ADR-018 Decision 7). Every row is tested through its
/// HONEST FAILURE path as well as its happy one: this screen's job is to never
/// claim a protection the platform refused.
const _uid = 'uid-1';
final _now = DateTime.utc(2026, 7, 10, 9);

void main() {
  final en = l10nFor(const Locale('en'));

  ({
    FakePinLockStore store,
    FakeAppIconSwitcher icons,
    FakeBiometricAuthenticator biometrics,
    FakeAuthRepository auth,
    FakeProfileRepository profiles,
    FakeDataRightsRepository dataRights,
    List<Override> overrides,
  })
  arrange({
    PinLockRecord? record,
    FakeAppIconSwitcher? icons,
    FakeBiometricAuthenticator? biometrics,
    RelationshipProfile? profile,
    FakeDataRightsRepository? dataRights,
  }) {
    final store = FakePinLockStore(initial: record);
    final iconSwitcher = icons ?? FakeAppIconSwitcher(supported: false);
    final biometricAuth =
        biometrics ?? FakeBiometricAuthenticator(available: false);
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: _uid, displayName: 'Aytek'),
    );
    final profiles = FakeProfileRepository(initialProfiles: {_uid: ?profile});
    final dataRightsRepo = dataRights ?? FakeDataRightsRepository();
    addTearDown(auth.dispose);
    addTearDown(profiles.dispose);
    return (
      store: store,
      icons: iconSwitcher,
      biometrics: biometricAuth,
      auth: auth,
      profiles: profiles,
      dataRights: dataRightsRepo,
      overrides: [
        pinLockStoreProvider.overrideWithValue(store),
        initialLockSnapshotProvider.overrideWithValue(
          PinLockSnapshot(record: record),
        ),
        biometricAuthenticatorProvider.overrideWithValue(biometricAuth),
        appIconSwitcherProvider.overrideWithValue(iconSwitcher),
        authRepositoryProvider.overrideWith((ref) => auth),
        profileRepositoryProvider.overrideWith((ref) => profiles),
        dataRightsRepositoryProvider.overrideWith((ref) => dataRightsRepo),
        soloClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
    );
  }

  Future<void> pumpSettings(
    WidgetTester tester,
    List<Override> overrides, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      localizedApp(
        const SettingsScreen(uid: _uid),
        locale: locale,
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('row 1 — the app lock', () {
    testWidgets('lock OFF offers set-up; the PIN setup flow enables it', (
      tester,
    ) async {
      final env = arrange();
      await pumpSettings(tester, env.overrides);

      expect(find.text(en.settingsLockSubtitleOff), findsOneWidget);
      expect(find.text(en.settingsLockSetUp), findsOneWidget);

      await tester.tap(find.text(en.settingsLockSetUp));
      await tester.pumpAndSettle();
      expect(find.byType(PinSetupScreen), findsOneWidget);

      await enterPin(tester, kTestPin); // enter
      await enterPin(tester, kTestPin); // confirm
      await tester.pumpAndSettle();

      // Back on settings, and the record actually persisted (never claim a lock
      // that did not reach the store — Decision 8).
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text(en.settingsLockSubtitleOn), findsOneWidget);
      expect(env.store.record?.isSet, isTrue);
    });

    testWidgets('lock ON: turning it off requires the PIN', (tester) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);

      expect(find.text(en.settingsLockSubtitleOn), findsOneWidget);
      await tester.tap(find.text(en.settingsLockTurnOff));
      await tester.pumpAndSettle();

      // A real dialog — legitimate HERE (this route is inside the Navigator),
      // unlike anywhere on the lock screen (Decision 3).
      expect(find.text(en.settingsLockVerifyTitle), findsOneWidget);
      await enterPin(tester, kTestPin);
      await tester.pumpAndSettle();

      expect(find.text(en.settingsLockSubtitleOff), findsOneWidget);
      expect(env.store.record, isNull);
    });

    testWidgets('a WRONG PIN leaves the lock on and says so', (tester) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.text(en.settingsLockTurnOff));
      await tester.pumpAndSettle();
      await enterPin(tester, kWrongPin);
      await tester.pumpAndSettle();

      expect(find.text(en.settingsLockDisableFailed), findsOneWidget);
      expect(find.text(en.settingsLockSubtitleOn), findsOneWidget);
      // The record survives — and the attempt was BOUNDED like any other
      // (disable would otherwise be an unbounded PIN oracle, Decision 4).
      expect(env.store.record?.isSet, isTrue);
      expect(env.store.record?.wrongCount, 1);
    });
  });

  group('row 1b — change PIN (ADR-018 rev 4)', () {
    testWidgets('the Change PIN row is HIDDEN when the lock is off '
        '(MUTATION-CHECK on the if(lockOn) guard)', (tester) async {
      final env = arrange();
      await pumpSettings(tester, env.overrides);
      expect(find.text(en.settingsChangePinTitle), findsNothing);
    });

    testWidgets('the Change PIN row SHOWS when the lock is on', (tester) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);
      expect(find.text(en.settingsChangePinTitle), findsOneWidget);
    });

    testWidgets('the happy path rotates the PIN — verify dialog, then the new-PIN '
        'screen, then back on settings with the new hash persisted', (
      tester,
    ) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);
      final oldSalt = env.store.record!.salt;

      await tester.tap(find.text(en.settingsChangePinTitle));
      await tester.pumpAndSettle();
      // The current-PIN dialog (pushed INSIDE the Navigator — legal here).
      expect(find.text(en.settingsLockVerifyTitle), findsOneWidget);
      await enterPin(tester, kTestPin);
      await tester.pumpAndSettle();

      // The collect-mode new-PIN screen, with its own prompt.
      expect(find.byType(PinSetupScreen), findsOneWidget);
      expect(find.text(en.settingsChangePinEnterPrompt), findsOneWidget);
      await enterPin(tester, kNewPin); // enter
      await enterPin(tester, kNewPin); // confirm
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      final rec = env.store.record!;
      expect(
        constantTimeEquals(hashPin(pin: kNewPin, salt: rec.salt), rec.pinHash),
        isTrue,
        reason: 'the new PIN is persisted',
      );
      expect(rec.salt, isNot(oldSalt), reason: 'a fresh salt per change');
      expect(rec.wrongCount, 0);
    });

    testWidgets('a WRONG current PIN shows the unchanged-PIN line and leaves the '
        'record untouched — bounded like disable', (tester) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);
      final oldHash = env.store.record!.pinHash;

      await tester.tap(find.text(en.settingsChangePinTitle));
      await tester.pumpAndSettle();
      await enterPin(tester, kWrongPin);
      await tester.pumpAndSettle();
      // The flow is atomic — the new-PIN screen still appears; the wrong current
      // PIN is only reported AFTER it (the accepted UX trade, ADR-018 rev 4).
      expect(find.byType(PinSetupScreen), findsOneWidget);
      await enterPin(tester, kNewPin);
      await enterPin(tester, kNewPin);
      await tester.pumpAndSettle();

      expect(find.text(en.settingsChangePinFailed), findsOneWidget);
      expect(env.store.record!.pinHash, oldHash, reason: 'PIN unchanged');
      expect(env.store.record!.wrongCount, 1, reason: 'the attempt is bounded');
    });

    testWidgets('a running cooldown shows the cooldown line, not a wrong-PIN '
        'line, and leaves the record unchanged (DVUX-4)', (tester) async {
      final until = _now.add(const Duration(seconds: 30)).millisecondsSinceEpoch;
      final env = arrange(
        record: lockRecord(wrongCount: 5, lockoutUntilMs: until),
      );
      await pumpSettings(tester, env.overrides);
      final oldHash = env.store.record!.pinHash;

      await tester.tap(find.text(en.settingsChangePinTitle));
      await tester.pumpAndSettle();
      await enterPin(tester, kTestPin);
      await tester.pumpAndSettle();
      await enterPin(tester, kNewPin);
      await enterPin(tester, kNewPin);
      await tester.pumpAndSettle();

      expect(find.text(en.settingsLockCooldown), findsOneWidget);
      expect(find.text(en.settingsChangePinFailed), findsNothing);
      expect(env.store.record!.pinHash, oldHash);
      expect(env.store.record!.wrongCount, 5, reason: 'not consumed');
    });

    testWidgets('a completed change PRESERVES the biometric row state', (
      tester,
    ) async {
      final env = arrange(
        record: lockRecord(biometricEnabled: true, enrollment: 'e1'),
        biometrics: FakeBiometricAuthenticator(
          available: true,
          enrollment: 'e1',
        ),
      );
      await pumpSettings(tester, env.overrides);
      expect(
        tester.widget<Switch>(find.byType(Switch).first).value,
        isTrue,
        reason: 'the biometric row starts on',
      );

      await tester.tap(find.text(en.settingsChangePinTitle));
      await tester.pumpAndSettle();
      await enterPin(tester, kTestPin);
      await tester.pumpAndSettle();
      await enterPin(tester, kNewPin);
      await enterPin(tester, kNewPin);
      await tester.pumpAndSettle();

      expect(env.store.record!.biometricEnabled, isTrue);
      expect(env.store.record!.biometricEnrollmentState, 'e1');
      expect(
        tester.widget<Switch>(find.byType(Switch).first).value,
        isTrue,
        reason: 'the accelerator survives the rotation',
      );
    });

    testWidgets('a FAILED new-PIN write shows the save-failed line and leaves the '
        'record unchanged — the old PIN is still in place (Decision 8)', (
      tester,
    ) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);
      final oldHash = env.store.record!.pinHash;
      env.store.onWrite = (_) async => throw StateError('keychain fault');

      await tester.tap(find.text(en.settingsChangePinTitle));
      await tester.pumpAndSettle();
      await enterPin(tester, kTestPin);
      await tester.pumpAndSettle();
      await enterPin(tester, kNewPin);
      await enterPin(tester, kNewPin);
      await tester.pumpAndSettle();

      expect(find.text(en.settingsChangePinSaveFailed), findsOneWidget);
      expect(
        env.store.record!.pinHash,
        oldHash,
        reason: 'never claim a rotation that did not persist',
      );
    });
  });

  group('row 2 — the biometric accelerator', () {
    testWidgets('hidden when the lock is off, even if biometrics are available', (
      tester,
    ) async {
      final env = arrange(biometrics: FakeBiometricAuthenticator());
      await pumpSettings(tester, env.overrides);
      // Biometric is only ever an accelerator FOR the PIN. With no PIN there is
      // nothing to accelerate — offering it would be the credential confusion
      // Decision 1 forbids.
      expect(find.text(en.settingsBiometricTitle), findsNothing);
    });

    testWidgets('enabling shows the DV WARNING and then demands the PIN', (
      tester,
    ) async {
      final env = arrange(
        record: lockRecord(),
        biometrics: FakeBiometricAuthenticator(),
      );
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // The warning is the whole DVUX-1 mitigation: the app cannot know whose
      // face is enrolled on a shared phone, and the user must weigh that.
      expect(find.text(en.settingsBiometricWarningTitle), findsOneWidget);
      expect(find.text(en.settingsBiometricWarningBody), findsOneWidget);
      // Nothing has been written yet.
      expect(env.store.callLog, isNot(contains('write:set')));

      await tester.tap(find.text(en.settingsBiometricWarningConfirm));
      await tester.pumpAndSettle();

      // Acknowledging the warning is NOT authorisation (review finding
      // LOCKBYPASS-2). Attaching a second credential to the lock demands the PIN,
      // exactly as removing the lock does — otherwise a partner holding a
      // momentarily-unlocked phone attaches their own enrolled face and keeps
      // permanent access without ever knowing the PIN.
      expect(
        env.store.record?.biometricEnabled,
        isFalse,
        reason: 'the warning alone must not enable it',
      );
      await enterPin(tester, kTestPin);
      await tester.pumpAndSettle();

      expect(env.store.record?.biometricEnabled, isTrue);
      expect(env.store.record?.biometricEnrollmentState, 'enrollment-v1');
    });

    testWidgets('a WRONG PIN leaves the accelerator off', (tester) async {
      final env = arrange(
        record: lockRecord(),
        biometrics: FakeBiometricAuthenticator(),
      );
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.settingsBiometricWarningConfirm));
      await tester.pumpAndSettle();
      await enterPin(tester, kWrongPin);
      await tester.pumpAndSettle();

      expect(env.store.record?.biometricEnabled, isFalse);
      expect(env.store.record?.biometricEnrollmentState, isNull);
      expect(find.text(en.settingsBiometricFailed), findsOneWidget);
    });

    testWidgets('declining the warning writes nothing and leaves it off', (
      tester,
    ) async {
      final env = arrange(
        record: lockRecord(),
        biometrics: FakeBiometricAuthenticator(),
      );
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.settingsCancel));
      await tester.pumpAndSettle();

      expect(env.store.record?.biometricEnabled, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    });

    testWidgets(
      'a platform with NO enrollment state to capture fails honestly',
      (tester) async {
        final env = arrange(
          record: lockRecord(),
          // Available, but the platform will not hand over an enrollment state —
          // so the revocation check could never run later. Refuse rather than
          // ship an accelerator we cannot invalidate (Decision 1).
          biometrics: FakeBiometricAuthenticator(enrollment: null),
        );
        await pumpSettings(tester, env.overrides);

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.settingsBiometricWarningConfirm));
        await tester.pumpAndSettle();
        await enterPin(tester, kTestPin);
        await tester.pumpAndSettle();

        expect(find.text(en.settingsBiometricFailed), findsOneWidget);
        expect(env.store.record?.biometricEnabled, isFalse);
        expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      },
    );
  });

  group('row 3 — the discreet icon', () {
    testWidgets('hidden when the platform has no alternate icons', (
      tester,
    ) async {
      final env = arrange(icons: FakeAppIconSwitcher(supported: false));
      await pumpSettings(tester, env.overrides);
      expect(find.text(en.settingsDiscreetTitle), findsNothing);
    });

    testWidgets('the subtitle carries the honest NAME-LABEL bound (DVUX-2)', (
      tester,
    ) async {
      final env = arrange(icons: FakeAppIconSwitcher());
      await pumpSettings(tester, env.overrides);
      // setAlternateIconName changes the IMAGE only; CFBundleDisplayName has no
      // runtime API. The copy must not imply the app disappears.
      expect(find.text(en.settingsDiscreetSubtitle), findsOneWidget);
    });

    testWidgets('toggling on applies the discreet icon', (tester) async {
      final env = arrange(icons: FakeAppIconSwitcher());
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(env.icons.callLog, contains('setDiscreet:true'));
      expect(env.icons.discreet, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    });

    testWidgets(
      'when the OS REFUSES, the switch REVERTS with honest copy — never a '
      'state the platform did not accept',
      (tester) async {
        final icons = FakeAppIconSwitcher()
          ..onSetDiscreet = (_) async =>
              throw const AppIconException('channel-error');
        final env = arrange(icons: icons);
        await pumpSettings(tester, env.overrides);

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        expect(find.text(en.settingsDiscreetFailed), findsOneWidget);
        expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
        // A user who believes a discreet icon is applied, and it is not, is the
        // worst lie this screen could tell (Decision 7's fail-direction row).
        expect(icons.discreet, isFalse);
      },
    );
  });

  group('row 4 — sign out', () {
    testWidgets('signs out through the auth controller', (tester) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.text(en.settingsSignOut));
      await tester.pumpAndSettle();

      expect(env.auth.signOutCalls, 1);
    });

    testWidgets('the subtitle says the PIN goes with it', (tester) async {
      final env = arrange(record: lockRecord());
      await pumpSettings(tester, env.overrides);
      // The lock is device-scoped and dies with the session (Decision 1) — a
      // surprise worth spending a line of copy on.
      expect(find.text(en.settingsSignOutSubtitle), findsOneWidget);
    });
  });

  const soloProfile = RelationshipProfile(
    status: RelationshipStatus.married,
    contentLanguage: ContentLanguage.tr,
    register: ContentRegister.playful,
  );
  const discreetProfile = RelationshipProfile(
    status: RelationshipStatus.married,
    contentLanguage: ContentLanguage.tr,
    register: ContentRegister.playful,
    notificationPrivacyDiscreet: true,
  );
  const arabicProfile = RelationshipProfile(
    status: RelationshipStatus.married,
    contentLanguage: ContentLanguage.ar,
    register: ContentRegister.respectful,
  );

  group('row 5 — discreet notifications (ADR-019 D6)', () {
    testWidgets('the switch is OFF when the explicit field is absent', (
      tester,
    ) async {
      final env = arrange(profile: soloProfile);
      await pumpSettings(tester, env.overrides);
      expect(find.text(en.settingsNotificationPrivacyTitle), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('the switch is ON when the explicit field is set', (
      tester,
    ) async {
      final env = arrange(profile: discreetProfile);
      await pumpSettings(tester, env.overrides);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('AR content shows the default-already-on subtitle', (
      tester,
    ) async {
      final env = arrange(profile: arabicProfile);
      await pumpSettings(tester, env.overrides);
      expect(
        find.text(en.settingsNotificationPrivacySubtitleAr),
        findsOneWidget,
      );
      expect(find.text(en.settingsNotificationPrivacySubtitle), findsNothing);
    });

    testWidgets('turning it ON writes discreet and the switch follows the '
        'profile stream round-trip', (tester) async {
      final env = arrange(profile: soloProfile);
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      // The callable was invoked with discreet: true (the explicit write).
      expect(env.dataRights.notificationPrivacyCalls, [true]);

      // Server truth re-emits on the profile stream; the switch follows it.
      env.profiles.emitProfile(_uid, discreetProfile);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('a failed write shows the honest error and the switch stays '
        'truthful to the server', (tester) async {
      final dataRights = FakeDataRightsRepository()
        ..onUpdateNotificationPrivacy = (_) async =>
            throw const DataRightsNetworkException();
      final env = arrange(profile: soloProfile, dataRights: dataRights);
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text(en.settingsNotificationPrivacyFailed), findsOneWidget);
      // The server did not change, so the switch reflects the old (false) truth.
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  group('data-rights rows (ADR-019 D5/D7)', () {
    testWidgets('free tier: all three data-rights additions render for a free '
        'user (a data right is not premium)', (tester) async {
      // No lock, no premium, an ordinary solo profile.
      final env = arrange(profile: soloProfile);
      await pumpSettings(tester, env.overrides);
      expect(find.text(en.dataRightsExportRowTitle), findsOneWidget);
      expect(find.text(en.dataRightsDeleteRowTitle), findsOneWidget);
      expect(find.text(en.settingsNotificationPrivacyTitle), findsOneWidget);
    });

    testWidgets('the download row pushes the export screen', (tester) async {
      final env = arrange(profile: soloProfile);
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.text(en.dataRightsExportRowTitle));
      await tester.pumpAndSettle();
      expect(find.byType(ExportScreen), findsOneWidget);
    });

    testWidgets('the delete row pushes the delete screen', (tester) async {
      final env = arrange(profile: soloProfile);
      await pumpSettings(tester, env.overrides);

      await tester.tap(find.text(en.dataRightsDeleteRowTitle));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });

    testWidgets('the Privacy & Terms row sits between Export and Delete and '
        'pushes the legal hub (ADR-023 D5/D9)', (tester) async {
      final env = arrange(profile: soloProfile);
      await pumpSettings(tester, env.overrides);

      final exportY = tester
          .getCenter(find.text(en.dataRightsExportRowTitle))
          .dy;
      final legalY = tester.getCenter(find.text(en.legalSettingsRowTitle)).dy;
      final deleteY = tester
          .getCenter(find.text(en.dataRightsDeleteRowTitle))
          .dy;
      expect(exportY, lessThan(legalY));
      expect(legalY, lessThan(deleteY));

      await tester.tap(find.text(en.legalSettingsRowTitle));
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
    });
  });
}
