import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';

void main() {
  group('AppFlavor', () {
    test('exposes exactly dev and prod', () {
      expect(AppFlavor.values, [AppFlavor.dev, AppFlavor.prod]);
    });
  });

  group('AppConfig', () {
    test('dev flavor is not prod', () {
      const config = AppConfig(flavor: AppFlavor.dev);
      expect(config.isProd, isFalse);
    });

    test('prod flavor is prod', () {
      const config = AppConfig(flavor: AppFlavor.prod);
      expect(config.isProd, isTrue);
    });

    test('appName defaults to the single brand constant', () {
      const config = AppConfig(flavor: AppFlavor.prod);
      expect(config.appName, kBrandName);
    });

    test('supports value equality', () {
      const a = AppConfig(flavor: AppFlavor.dev);
      const b = AppConfig(flavor: AppFlavor.dev);
      const c = AppConfig(flavor: AppFlavor.prod);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
