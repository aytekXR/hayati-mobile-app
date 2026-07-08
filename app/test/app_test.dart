import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/app.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';

import 'support/fake_auth_repository.dart';

void main() {
  Future<void> pumpFlavor(WidgetTester tester, AppFlavor flavor) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig(flavor: flavor)),
          // Widget tests compose the same seam the entrypoints use
          // (runHayati extraOverrides) with a fake instead of Firebase.
          authRepositoryProvider.overrideWith((ref) => fake),
        ],
        child: const HayatiApp(),
      ),
    );
  }

  group('HayatiApp', () {
    testWidgets('boots into the auth shell with the dev flavor', (
      tester,
    ) async {
      await pumpFlavor(tester, AppFlavor.dev);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(kBrandName), findsOneWidget);
    });

    testWidgets('boots into the auth shell with the prod flavor', (
      tester,
    ) async {
      await pumpFlavor(tester, AppFlavor.prod);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(kBrandName), findsOneWidget);
    });
  });
}
