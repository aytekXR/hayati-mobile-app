import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_exception.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/data_rights/presentation/delete_account_screen.dart';
import 'package:hayati_app/features/data_rights/presentation/export_screen.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/settings/domain/app_icon_switcher.dart';
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

const _uid = 'uid-1';
const _soloProfile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
);

void main() {
  final en = l10nFor(const Locale('en'));

  ({
    FakeAuthRepository auth,
    FakeDataRightsRepository dataRights,
    FakePinLockStore store,
    List<Override> overrides,
  })
  arrange({PinLockRecord? record, FakeDataRightsRepository? dataRights}) {
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: _uid, displayName: 'Aytek'),
    );
    final dataRightsRepo = dataRights ?? FakeDataRightsRepository();
    final profiles = FakeProfileRepository(
      initialProfiles: const {_uid: _soloProfile},
    );
    final store = FakePinLockStore(initial: record);
    addTearDown(auth.dispose);
    addTearDown(profiles.dispose);
    return (
      auth: auth,
      dataRights: dataRightsRepo,
      store: store,
      overrides: [
        pinLockStoreProvider.overrideWithValue(store),
        initialLockSnapshotProvider.overrideWithValue(
          PinLockSnapshot(record: record),
        ),
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(available: false),
        ),
        appIconSwitcherProvider.overrideWithValue(
          FakeAppIconSwitcher(supported: false),
        ),
        authRepositoryProvider.overrideWith((ref) => auth),
        profileRepositoryProvider.overrideWith((ref) => profiles),
        dataRightsRepositoryProvider.overrideWith((ref) => dataRightsRepo),
      ],
    );
  }

  /// Pumps the SettingsScreen (whose auth-loss self-pop listener stays LIVE in
  /// the tree — the APP-1 pin) and navigates into the DeleteAccountScreen the way
  /// a user does, via the row.
  Future<void> pumpViaSettings(
    WidgetTester tester,
    List<Override> overrides,
  ) async {
    await tester.pumpWidget(
      localizedApp(const SettingsScreen(uid: _uid), overrides: overrides),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.dataRightsDeleteRowTitle));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  }

  group('the consequence copy (ADR-019 D7 pins)', () {
    testWidgets('states irreversible, both-sides scope, partner, subscription', (
      tester,
    ) async {
      final env = arrange();
      await pumpViaSettings(tester, env.overrides);

      expect(find.text(en.dataRightsDeleteIrreversible), findsOneWidget);
      expect(find.text(en.dataRightsDeleteScope), findsOneWidget);
      expect(find.text(en.dataRightsDeletePartner), findsOneWidget);
      expect(find.text(en.dataRightsDeleteSubscription), findsOneWidget);
      expect(find.text(en.dataRightsDeleteExportLink), findsOneWidget);

      // The both-sides + subscription copy pins (content-level, not screenshot).
      expect(en.dataRightsDeleteScope, contains('both sides'));
      expect(
        en.dataRightsDeleteSubscription.toLowerCase(),
        contains('app store'),
      );
    });

    testWidgets('the download-your-data link opens the export screen', (
      tester,
    ) async {
      final env = arrange();
      await pumpViaSettings(tester, env.overrides);

      await tester.tap(find.text(en.dataRightsDeleteExportLink));
      await tester.pumpAndSettle();
      expect(find.byType(ExportScreen), findsOneWidget);
    });
  });

  group('the confirm step', () {
    testWidgets('lock OFF → a plain destructive dialog naming "permanently"', (
      tester,
    ) async {
      final env = arrange();
      await pumpViaSettings(tester, env.overrides);

      await tester.tap(find.text(en.dataRightsDeleteConfirmAction));
      await tester.pumpAndSettle();

      expect(find.text(en.dataRightsDeleteDialogTitle), findsOneWidget);
      expect(en.dataRightsDeleteDialogBody, contains('permanently'));

      await tester.tap(find.text(en.dataRightsDeleteDialogConfirm));
      await tester.pumpAndSettle();
      expect(env.dataRights.deleteAccountCalls, 1);
    });

    testWidgets(
      'lock ON → the PIN-verify dialog, and the correct PIN proceeds',
      (tester) async {
        final env = arrange(record: lockRecord());
        await pumpViaSettings(tester, env.overrides);

        await tester.tap(find.text(en.dataRightsDeleteConfirmAction));
        await tester.pumpAndSettle();

        // The PIN dialog, not the plain one (Invariant C — PIN re-auth).
        expect(find.text(en.settingsLockVerifyTitle), findsOneWidget);
        expect(find.text(en.dataRightsDeleteDialogTitle), findsNothing);

        await enterPin(tester, kTestPin);
        await tester.pumpAndSettle();
        expect(env.dataRights.deleteAccountCalls, 1);
        expect(env.auth.signOutAfterAccountDeletionCalls, 1);
      },
    );
  });

  group('phase-1 cascade failure (APP-1)', () {
    testWidgets(
      'the screen SURVIVES with retry copy while the host SettingsScreen '
      'listener is live — and the copy says "could not be confirmed", never '
      '"failed"',
      (tester) async {
        final dataRights = FakeDataRightsRepository()
          ..onDeleteAccount = () async =>
              throw const DataRightsNetworkException();
        final env = arrange(dataRights: dataRights);
        await pumpViaSettings(tester, env.overrides);

        await tester.tap(find.text(en.dataRightsDeleteConfirmAction));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.dataRightsDeleteDialogConfirm));
        await tester.pumpAndSettle();

        // Nothing popped: the delete screen is still here AND the host settings
        // screen is still MOUNTED behind it (offstage but live — its self-pop
        // listener never fired, because the auth state never left AuthSignedIn).
        expect(find.byType(DeleteAccountScreen), findsOneWidget);
        expect(
          find.byType(SettingsScreen, skipOffstage: false),
          findsOneWidget,
        );

        // The honest retry copy — and it must NOT say "failed" (AUTH-3).
        expect(find.text(en.dataRightsDeleteCouldNotConfirm), findsOneWidget);
        expect(
          en.dataRightsDeleteCouldNotConfirm.toLowerCase(),
          isNot(contains('failed')),
        );
      },
    );
  });
}
