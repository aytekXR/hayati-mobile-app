import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/local_flag_store.dart';
import 'package:hayati_app/core/storage/shared_preferences_local_flag_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_local_flag_store.dart';

/// The [LocalFlagStore] seam, including the account-scoped removal ADR-061 adds.
///
/// **Both implementations run the same removal cases.** The fake is what every
/// widget test uses and the prefs adapter is what ships; a sweep that worked in
/// one and not the other would be a deletion defect nobody saw, so the cases are
/// written once and applied to both (`runRemovalCases`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'u1';
  const otherUid = 'u12';

  LocalFlagKey account(AccountFlag flag, String forUid) =>
      LocalFlagKey.account(flag, uid: forUid);
  LocalFlagKey device(DeviceFlag flag) => LocalFlagKey.device(flag);

  group('FakeLocalFlagStore', () {
    test('reports unset keys false and set keys true', () async {
      final store = FakeLocalFlagStore();
      final key = account(AccountFlag.coachDisclaimerAck, uid);

      expect(store.isSet(key), isFalse);
      await store.set(key);
      expect(store.isSet(key), isTrue);
      expect(
        store.isSet(account(AccountFlag.coachDisclaimerAck, 'u2')),
        isFalse,
      );
    });

    test('respects pre-seeded flags', () {
      final store = FakeLocalFlagStore(
        initial: {account(AccountFlag.nameCaptureDone, uid).value},
      );
      expect(store.isSet(account(AccountFlag.nameCaptureDone, uid)), isTrue);
    });
  });

  group('SharedPreferencesLocalFlagStore', () {
    test(
      'reads false when unset, true after set (through the prefs cache)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesLocalFlagStore(prefs);
        final key = account(AccountFlag.coachDisclaimerAck, uid);

        expect(store.isSet(key), isFalse);
        await store.set(key);
        expect(store.isSet(key), isTrue);
      },
    );

    test('reads a pre-seeded true synchronously off the cache', () async {
      final key = account(AccountFlag.coachDisclaimerAck, 'u2');
      SharedPreferences.setMockInitialValues({key.value: true});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesLocalFlagStore(prefs);

      // Synchronous read — no await between construction and the check.
      expect(store.isSet(key), isTrue);
    });
  });

  /// The ADR-061 D1 sweep, run against whichever store [make] returns.
  ///
  /// [make] is handed the keys to seed, because the two implementations are
  /// seeded differently (a set for the fake, mock prefs for the adapter) and the
  /// point of this group is that they behave the SAME afterwards.
  void runRemovalCases(
    String label,
    Future<LocalFlagStore> Function(List<LocalFlagKey>) make,
  ) {
    group('removeAccountScoped — $label', () {
      test('removes every account flag this uid owns', () async {
        final mine = [
          for (final flag in AccountFlag.values) account(flag, uid),
        ];
        final store = await make(mine);
        for (final key in mine) {
          expect(store.isSet(key), isTrue, reason: 'seed failed for $key');
        }

        await store.removeAccountScoped(uid);

        for (final key in mine) {
          expect(
            store.isSet(key),
            isFalse,
            reason: '$key survived the deletion of its own account',
          );
        }
      });

      test('leaves both DEVICE flags exactly where they were', () async {
        final deviceKeys = [for (final f in DeviceFlag.values) device(f)];
        final store = await make([
          ...deviceKeys,
          account(AccountFlag.signup, uid),
        ]);

        await store.removeAccountScoped(uid);

        for (final key in deviceKeys) {
          expect(
            store.isSet(key),
            isTrue,
            reason:
                '$key is device state — clearing it re-emits install or '
                're-shows the pre-sign-in preview (ADR-061 finding 3)',
          );
        }
      });

      test(
        'leaves ANOTHER account\'s flags alone on a shared device',
        () async {
          final theirs = [
            for (final flag in AccountFlag.values) account(flag, otherUid),
          ];
          final store = await make([
            ...theirs,
            account(AccountFlag.signup, uid),
          ]);

          await store.removeAccountScoped(uid);

          expect(store.isSet(account(AccountFlag.signup, uid)), isFalse);
          for (final key in theirs) {
            expect(
              store.isSet(key),
              isTrue,
              reason:
                  '$key belongs to "$otherUid", not "$uid" — a substring match '
                  'would have taken it',
            );
          }
        },
      );

      test('removes keys with trailing coordinates', () async {
        final paired = LocalFlagKey.account(
          AccountFlag.paired,
          uid: uid,
          parts: const ['couple-1'],
        );
        final answered = LocalFlagKey.account(
          AccountFlag.qAnswered,
          uid: uid,
          parts: const ['20260818', 'solo'],
        );
        final store = await make([paired, answered]);

        await store.removeAccountScoped(uid);

        expect(store.isSet(paired), isFalse);
        expect(store.isSet(answered), isFalse);
      });

      test('an empty uid removes nothing and does not throw', () async {
        final all = [
          for (final flag in AccountFlag.values) account(flag, uid),
          for (final flag in DeviceFlag.values) device(flag),
        ];
        final store = await make(all);

        await store.removeAccountScoped('');

        for (final key in all) {
          expect(store.isSet(key), isTrue, reason: '$key was wildcard-matched');
        }
      });

      test('removing an unknown account is a no-op, not an error', () async {
        final all = [for (final flag in AccountFlag.values) account(flag, uid)];
        final store = await make(all);

        await store.removeAccountScoped('nobody');

        for (final key in all) {
          expect(store.isSet(key), isTrue);
        }
      });
    });
  }

  runRemovalCases('FakeLocalFlagStore', (keys) async {
    return FakeLocalFlagStore(initial: {for (final k in keys) k.value});
  });

  runRemovalCases('SharedPreferencesLocalFlagStore', (keys) async {
    SharedPreferences.setMockInitialValues({
      for (final k in keys) k.value: true,
      // A foreign key from another package sharing the prefs domain: the sweep
      // must not depend on every key being one of ours, and must not take one
      // that is not (ADR-061 Consequences).
      'some.other.plugin.setting': true,
    });
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesLocalFlagStore(prefs);
  });

  test('the prefs sweep leaves a foreign key untouched', () async {
    SharedPreferences.setMockInitialValues({
      LocalFlagKey.account(AccountFlag.signup, uid: uid).value: true,
      'some.other.plugin.setting': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesLocalFlagStore(prefs);

    await store.removeAccountScoped(uid);

    expect(prefs.getBool('some.other.plugin.setting'), isTrue);
  });
}
