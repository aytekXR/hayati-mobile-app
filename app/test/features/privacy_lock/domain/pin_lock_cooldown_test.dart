import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/privacy_lock/domain/pin_lock_cooldown.dart';

void main() {
  group('cooldownFor (ADR-018 Decision 4 schedule)', () {
    test('attempts 1-4 are free', () {
      expect(cooldownFor(0), isNull);
      expect(cooldownFor(1), isNull);
      expect(cooldownFor(2), isNull);
      expect(cooldownFor(3), isNull);
      expect(cooldownFor(4), isNull);
    });

    test('the 5th wrong attempt starts a 30s cooldown', () {
      expect(cooldownFor(5), const Duration(seconds: 30));
    });

    test('the 6th wrong attempt is a 1 minute cooldown', () {
      expect(cooldownFor(6), const Duration(minutes: 1));
    });

    test('the 7th and every later attempt is a 5 minute cooldown', () {
      expect(cooldownFor(7), const Duration(minutes: 5));
      expect(cooldownFor(8), const Duration(minutes: 5));
      expect(cooldownFor(12), const Duration(minutes: 5));
      expect(cooldownFor(1000), const Duration(minutes: 5));
    });

    test('a negative count (corrupt record) is treated as free, never throws', () {
      expect(cooldownFor(-1), isNull);
    });
  });

  group('cooldownTierFor (tier-accurate copy — review finding DVUX-5)', () {
    test('maps each wrongCount to the tier the UI must name honestly', () {
      expect(cooldownTierFor(4), isNull);
      expect(cooldownTierFor(5), PinLockCooldownTier.thirtySeconds);
      expect(cooldownTierFor(6), PinLockCooldownTier.oneMinute);
      expect(cooldownTierFor(7), PinLockCooldownTier.fiveMinutes);
      expect(cooldownTierFor(30), PinLockCooldownTier.fiveMinutes);
    });
  });

  group('remainingBeforeCooldown', () {
    test('counts down the free attempts and floors at zero', () {
      expect(remainingBeforeCooldown(0), 4);
      expect(remainingBeforeCooldown(1), 3);
      expect(remainingBeforeCooldown(4), 0);
      expect(remainingBeforeCooldown(5), 0);
      expect(remainingBeforeCooldown(9), 0);
    });
  });
}
