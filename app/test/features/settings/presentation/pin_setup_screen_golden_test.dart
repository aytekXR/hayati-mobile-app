import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/settings/presentation/pin_setup_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_pin_lock_store.dart';
import '../../../support/golden/golden_harness.dart';
import '../../../support/pin_lock_fixtures.dart';

/// PIN setup, first phase. Same LTR-pinned pad as the lock screen — the AR/RTL
/// cells pin that it does not mirror (review finding DVUX-6).
final _now = DateTime.utc(2026, 7, 10, 9);

void main() {
  List<Override> arrange() => [
    pinLockStoreProvider.overrideWithValue(FakePinLockStore()),
    initialLockSnapshotProvider.overrideWithValue(noLockSnapshot),
    biometricAuthenticatorProvider.overrideWithValue(
      FakeBiometricAuthenticator(available: false),
    ),
    soloClockProvider.overrideWith(
      (ref) =>
          () => _now,
    ),
  ];

  for (final cell in sixCells) {
    testWidgets('enter ${cell.suffix}', (tester) async {
      await pumpGolden(
        tester,
        const PinSetupScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: arrange(),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PinSetupScreen),
        matchesGoldenFile(goldenFile('pin_setup_screen', 'enter', cell.suffix)),
      );
    });
  }
}
