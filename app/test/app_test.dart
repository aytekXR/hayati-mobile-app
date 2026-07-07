import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/app.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';

void main() {
  Future<void> pumpFlavor(WidgetTester tester, AppFlavor flavor) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig(flavor: flavor)),
        ],
        child: const HayatiApp(),
      ),
    );
  }

  group('HayatiApp', () {
    testWidgets('boots with the dev flavor', (tester) async {
      await pumpFlavor(tester, AppFlavor.dev);
      expect(find.text('dev'), findsOneWidget);
    });

    testWidgets('boots with the prod flavor', (tester) async {
      await pumpFlavor(tester, AppFlavor.prod);
      expect(find.text('prod'), findsOneWidget);
    });
  });
}
