import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';

void main() {
  group('appConfigProvider', () {
    test('throws when not overridden by a flavor entrypoint', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Riverpod 3 wraps provider-body errors, so match on the contract
      // message rather than the raw StateError type.
      expect(
        () => container.read(appConfigProvider),
        throwsA(
          predicate<Object>((e) => e.toString().contains('must be overridden')),
        ),
      );
    });

    test('returns the flavor config it was overridden with', () {
      const devConfig = AppConfig(flavor: AppFlavor.dev);
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(devConfig)],
      );
      addTearDown(container.dispose);
      expect(container.read(appConfigProvider), devConfig);
    });
  });
}
