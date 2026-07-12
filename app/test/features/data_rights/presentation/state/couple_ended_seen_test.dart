import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/presentation/state/couple_ended_seen.dart';

void main() {
  group('coupleEndedSeenKey', () {
    test('embeds the uid and the event epoch-ms', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1752000000000);
      expect(
        coupleEndedSeenKey('uid-B', at),
        'coupleEndedSeen.uid-B.1752000000000',
      );
    });

    test('a different event time mints a DIFFERENT key (NOTICE-1)', () {
      final first = DateTime.fromMillisecondsSinceEpoch(1752000000000);
      final second = DateTime.fromMillisecondsSinceEpoch(1752999999999);
      expect(
        coupleEndedSeenKey('uid-B', first),
        isNot(coupleEndedSeenKey('uid-B', second)),
      );
    });

    test('per-uid keying keeps the flag from leaking across accounts', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1752000000000);
      expect(
        coupleEndedSeenKey('uid-A', at),
        isNot(coupleEndedSeenKey('uid-B', at)),
      );
    });
  });

  group('coupleEndedSeenProvider', () {
    test('seeds to 0 and bumps on markSeen (the reactive gate signal)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(coupleEndedSeenProvider), 0);
      container.read(coupleEndedSeenProvider.notifier).markSeen();
      expect(container.read(coupleEndedSeenProvider), 1);
    });
  });
}
