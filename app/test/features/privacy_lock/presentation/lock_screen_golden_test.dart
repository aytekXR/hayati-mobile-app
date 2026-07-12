import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/privacy_lock/presentation/lock_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_pin_lock_store.dart';
import '../../../support/golden/golden_harness.dart';
import '../../../support/pin_lock_fixtures.dart';

/// The lock screen's six-cell matrix. The AR/RTL cells carry a load-bearing
/// assertion no `expect` makes as legibly: **the keypad is NOT mirrored** —
/// 1-2-3 still reads left-to-right while every line of copy around it flips
/// (ADR-018 Decision 1; review finding DVUX-6).
final _now = DateTime.utc(2026, 7, 10, 9);
final _nowMs = _now.millisecondsSinceEpoch;

enum _State {
  /// Fresh lock screen with the biometric accelerator offered.
  locked,

  /// Attempts exhausted: pad disabled, tier-accurate copy (DVUX-5).
  cooldown,
}

void main() {
  List<Override> arrange(_State state) {
    final record = switch (state) {
      _State.locked => lockRecord(
        biometricEnabled: true,
        enrollment: 'enrollment-v1',
      ),
      _State.cooldown => lockRecord(
        wrongCount: 5,
        lockoutUntilMs: _nowMs + const Duration(seconds: 30).inMilliseconds,
      ),
    };
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
        FakeBiometricAuthenticator(enrollment: 'enrollment-v1'),
      ),
      authRepositoryProvider.overrideWith((ref) => auth),
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
      const LockScreen(),
      locale: cell.locale,
      direction: cell.direction,
      overrides: arrange(state),
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  for (final state in _State.values) {
    for (final cell in sixCells) {
      testWidgets('${state.name} ${cell.suffix}', (tester) async {
        await pump(tester, cell, state);
        await expectLater(
          find.byType(LockScreen),
          matchesGoldenFile(goldenFile('lock_screen', state.name, cell.suffix)),
        );
      });
    }

    // Dynamic-type probe, natural directions only.
    for (final cell in naturalCells) {
      testWidgets('${state.name} scale130 ${cell.suffix}', (tester) async {
        await pump(tester, cell, state, textScale: 1.3);
        await expectLater(
          find.byType(LockScreen),
          matchesGoldenFile(
            goldenFile('lock_screen', '${state.name}.scale130', cell.suffix),
          ),
        );
      });
    }
  }
}
