import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/config/app_config.dart';
import 'package:hayati_app/core/config/app_config_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_exception.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/presentation/sign_in_screen.dart';
import 'package:hayati_app/features/pairing/domain/deep_link_source.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_deep_link_source.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/golden/golden_harness.dart';
import '../../../support/localized_app.dart';

// The AuthSigningIn spinner state is deliberately NOT golden'd: an indeterminate
// CircularProgressIndicator has no stable frame. sign_in_screen_test.dart covers
// it behaviourally (find.byType(CircularProgressIndicator)).
void main() {
  for (final cell in sixCells) {
    testWidgets('signed_out ${cell.suffix}', (tester) async {
      final auth = FakeAuthRepository();
      final profiles = FakeProfileRepository();
      final deepLinks = FakeDeepLinkSource();
      addTearDown(auth.dispose);
      addTearDown(profiles.dispose);
      addTearDown(deepLinks.dispose);

      await pumpGolden(
        tester,
        const SignInScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: AppFlavor.dev),
          ),
          authRepositoryProvider.overrideWith((ref) => auth),
          profileRepositoryProvider.overrideWith((ref) => profiles),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
        ],
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SignInScreen),
        matchesGoldenFile(
          goldenFile('sign_in_screen', 'signed_out', cell.suffix),
        ),
      );
    });

    testWidgets('error ${cell.suffix}', (tester) async {
      final auth = FakeAuthRepository();
      final profiles = FakeProfileRepository();
      final deepLinks = FakeDeepLinkSource();
      addTearDown(auth.dispose);
      addTearDown(profiles.dispose);
      addTearDown(deepLinks.dispose);
      auth.onSignInWithGoogle = () async {
        throw const AuthNetworkException(message: 'offline');
      };

      await pumpGolden(
        tester,
        const SignInScreen(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: AppFlavor.dev),
          ),
          authRepositoryProvider.overrideWith((ref) => auth),
          profileRepositoryProvider.overrideWith((ref) => profiles),
          deepLinkSourceProvider.overrideWith((ref) => deepLinks),
        ],
      );
      await tester.pumpAndSettle();
      // Copy is per-locale, so resolve the button label through l10nFor.
      await tester.tap(find.text(l10nFor(cell.locale).continueWithGoogle));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SignInScreen),
        matchesGoldenFile(goldenFile('sign_in_screen', 'error', cell.suffix)),
      );
    });
  }
}
