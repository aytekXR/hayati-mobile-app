import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/shared_preferences_local_flag_store.dart';
import 'package:hayati_app/features/coach/domain/coach_disclaimer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_local_flag_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeLocalFlagStore', () {
    test('reports unset keys false and set keys true', () async {
      final store = FakeLocalFlagStore();

      expect(store.isSet('k'), isFalse);
      await store.set('k');
      expect(store.isSet('k'), isTrue);
      expect(store.isSet('other'), isFalse);
    });

    test('respects pre-seeded flags', () {
      final store = FakeLocalFlagStore(initial: {'seed'});
      expect(store.isSet('seed'), isTrue);
    });
  });

  group('SharedPreferencesLocalFlagStore', () {
    test(
      'reads false when unset, true after set (through the prefs cache)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesLocalFlagStore(prefs);
        final key = coachDisclaimerAckKey('u1');

        expect(store.isSet(key), isFalse);
        await store.set(key);
        expect(store.isSet(key), isTrue);
      },
    );

    test('reads a pre-seeded true synchronously off the cache', () async {
      SharedPreferences.setMockInitialValues({
        coachDisclaimerAckKey('u2'): true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesLocalFlagStore(prefs);

      // Synchronous read — no await between construction and the check.
      expect(store.isSet(coachDisclaimerAckKey('u2')), isTrue);
    });
  });

  group('coachDisclaimerAckKey', () {
    test('is uid-namespaced so a second account is not treated as acked', () {
      expect(coachDisclaimerAckKey('u1'), 'coachDisclaimerAck.u1');
      expect(coachDisclaimerAckKey('u1'), isNot(coachDisclaimerAckKey('u2')));
    });
  });
}
