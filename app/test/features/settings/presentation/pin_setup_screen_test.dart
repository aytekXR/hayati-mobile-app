import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/privacy_lock/presentation/widgets/pin_keypad.dart';
import 'package:hayati_app/features/settings/presentation/pin_setup_screen.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation exposes it.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_pin_lock_store.dart';
import '../../../support/localized_app.dart';
import '../../../support/pin_lock_fixtures.dart';

/// PIN setup (ADR-018 Decision 1): enter → confirm → persisted. The two paths
/// that matter are the ones where the user gets it wrong and where the STORE
/// does: neither may end with the app claiming a lock it does not have.
final _now = DateTime.utc(2026, 7, 10, 9);

void main() {
  final en = l10nFor(const Locale('en'));

  ({FakePinLockStore store, List<Override> overrides}) arrange() {
    final store = FakePinLockStore();
    return (
      store: store,
      overrides: [
        pinLockStoreProvider.overrideWithValue(store),
        initialLockSnapshotProvider.overrideWithValue(noLockSnapshot),
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(available: false),
        ),
        soloClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
    );
  }

  Future<void> pumpSetup(WidgetTester tester, List<Override> overrides) async {
    await tester.pumpWidget(
      localizedApp(const PinSetupScreen(), overrides: overrides),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('enter → confirm → the record is written', (tester) async {
    final env = arrange();
    await pumpSetup(tester, env.overrides);

    expect(find.text(en.settingsPinEnterPrompt), findsOneWidget);
    await enterPin(tester, kTestPin);

    expect(find.text(en.settingsPinConfirmPrompt), findsOneWidget);
    // The dots reset for the second entry: nothing carries over on screen.
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 0);

    await enterPin(tester, kTestPin);
    await tester.pumpAndSettle();

    expect(env.store.record?.isSet, isTrue);
    // PRESENCE only in the fake's log — a fixture that printed a salt would be
    // the no-content rule leaking through the back door.
    expect(env.store.callLog, contains('write:set'));
  });

  testWidgets('a MISMATCH restarts the flow with honest copy', (tester) async {
    final env = arrange();
    await pumpSetup(tester, env.overrides);

    await enterPin(tester, kTestPin);
    await enterPin(tester, kWrongPin);
    await tester.pumpAndSettle();

    expect(find.text(en.settingsPinMismatch), findsOneWidget);
    // Back to phase one, dots empty, nothing persisted.
    expect(find.text(en.settingsPinEnterPrompt), findsOneWidget);
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 0);
    expect(env.store.record, isNull);
    expect(env.store.callLog, isEmpty);
  });

  testWidgets('a failed WRITE reports failure and leaves the lock OFF', (
    tester,
  ) async {
    final env = arrange();
    env.store.onWrite = (_) async => throw StateError('keychain unavailable');
    await pumpSetup(tester, env.overrides);

    await enterPin(tester, kTestPin);
    await enterPin(tester, kTestPin);
    await tester.pumpAndSettle();

    // Never claim protection that did not persist (Decision 8's row).
    expect(find.text(en.settingsPinSaveFailed), findsOneWidget);
    expect(find.text(en.settingsPinEnterPrompt), findsOneWidget);
    expect(env.store.record, isNull);
  });

  testWidgets('backspace deletes one digit', (tester) async {
    final env = arrange();
    await pumpSetup(tester, env.overrides);

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 2);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 1);
  });
}
