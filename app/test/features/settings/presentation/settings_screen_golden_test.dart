import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
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
import '../../../support/golden/golden_harness.dart';
import '../../../support/pin_lock_fixtures.dart';

/// The settings surface across the matrix. Both states render the discreet-icon
/// row (its subtitle carries the honest name-label bound — DVUX-2), and the
/// lock-on state additionally reveals the biometric row: the accelerator exists
/// only where there is a PIN to accelerate.
const _uid = 'uid-1';
final _now = DateTime.utc(2026, 7, 10, 9);

enum _State { lockOff, lockOn }

extension on _State {
  String get slug => switch (this) {
    _State.lockOff => 'lock_off',
    _State.lockOn => 'lock_on',
  };
}

void main() {
  // A fixed non-Arabic solo profile with no explicit override so the discreet-
  // notifications row renders deterministically (switch off, the normal subtitle)
  // across every locale cell — the AR-subtitle variant is a widget-test concern.
  const seededProfile = RelationshipProfile(
    status: RelationshipStatus.married,
    contentLanguage: ContentLanguage.tr,
    register: ContentRegister.playful,
  );

  List<Override> arrange(_State state) {
    final record = state == _State.lockOn ? lockRecord() : null;
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: _uid, displayName: 'Aytek'),
    );
    final profiles = FakeProfileRepository(
      initialProfiles: const {_uid: seededProfile},
    );
    addTearDown(auth.dispose);
    addTearDown(profiles.dispose);
    return [
      pinLockStoreProvider.overrideWithValue(FakePinLockStore(initial: record)),
      initialLockSnapshotProvider.overrideWithValue(
        PinLockSnapshot(record: record),
      ),
      biometricAuthenticatorProvider.overrideWithValue(
        FakeBiometricAuthenticator(),
      ),
      appIconSwitcherProvider.overrideWithValue(FakeAppIconSwitcher()),
      authRepositoryProvider.overrideWith((ref) => auth),
      profileRepositoryProvider.overrideWith((ref) => profiles),
      dataRightsRepositoryProvider.overrideWith(
        (ref) => FakeDataRightsRepository(),
      ),
      soloClockProvider.overrideWith(
        (ref) =>
            () => _now,
      ),
    ];
  }

  Future<void> pump(
    WidgetTester tester,
    GoldenCell cell,
    _State state, {
    double textScale = 1.0,
  }) async {
    await pumpGolden(
      tester,
      const SettingsScreen(uid: _uid),
      locale: cell.locale,
      direction: cell.direction,
      overrides: arrange(state),
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  for (final state in _State.values) {
    for (final cell in sixCells) {
      testWidgets('${state.slug} ${cell.suffix}', (tester) async {
        await pump(tester, cell, state);
        await expectLater(
          find.byType(SettingsScreen),
          matchesGoldenFile(
            goldenFile('settings_screen', state.slug, cell.suffix),
          ),
        );
      });
    }

    for (final cell in naturalCells) {
      testWidgets('${state.slug} scale130 ${cell.suffix}', (tester) async {
        await pump(tester, cell, state, textScale: 1.3);
        await expectLater(
          find.byType(SettingsScreen),
          matchesGoldenFile(
            goldenFile(
              'settings_screen',
              '${state.slug}.scale130',
              cell.suffix,
            ),
          ),
        );
      });
    }
  }
}
