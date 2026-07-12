import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/settings/domain/app_icon_switcher.dart';

import '../../../support/fake_app_icon_switcher.dart';

void main() {
  group('AppIconException (ADR-018 Decisions 6/7)', () {
    test('carries a CODE and nothing else — the no-content rule', () {
      const failure = AppIconException('channel-error');

      expect(failure.code, 'channel-error');
      expect(failure.toString(), 'AppIconException(code: channel-error)');
      // Crashlytics is on in prod and the global hooks forward toString()s: no
      // user data, no PIN, no OS-supplied message may ever ride along here.
      expect(failure.toString().split(':'), hasLength(2));
    });

    test('is value-equal (so a UI can match on it)', () {
      expect(const AppIconException('x'), const AppIconException('x'));
      expect(const AppIconException('x'), isNot(const AppIconException('y')));
    });
  });

  group('FakeAppIconSwitcher', () {
    test('applies the discreet icon and records the call', () async {
      final switcher = FakeAppIconSwitcher();

      expect(await switcher.supportsAlternateIcons(), isTrue);
      expect(await switcher.isDiscreet(), isFalse);
      await switcher.setDiscreet(true);
      expect(await switcher.isDiscreet(), isTrue);

      expect(switcher.callLog, [
        'supportsAlternateIcons',
        'isDiscreet',
        'setDiscreet:true',
        'isDiscreet',
      ]);
    });

    test(
      'a refused set THROWS and leaves the applied state untouched — the toggle '
      'must revert, never claim a state the OS refused (D7)',
      () async {
        final switcher = FakeAppIconSwitcher()
          ..onSetDiscreet =
              (_) async => throw const AppIconException('channel-error');

        await expectLater(
          switcher.setDiscreet(true),
          throwsA(const AppIconException('channel-error')),
        );
        expect(switcher.discreet, isFalse);
      },
    );
  });

  test('the alternate icon set name matches the asset catalog (D6)', () {
    expect(kDiscreetIconName, 'AppIconDiscreet');
  });
}
