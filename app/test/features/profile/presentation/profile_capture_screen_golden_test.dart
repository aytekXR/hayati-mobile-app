import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/presentation/profile_capture_screen.dart';

import '../../../support/fake_profile_repository.dart';
import '../../../support/golden/golden_harness.dart';

// The in-flight save (CaptureSaving) spinner and the CaptureFailure error view
// are deliberately NOT golden'd here: the spinner is indeterminate, and the
// error view is covered behaviourally by profile_capture_screen_test.dart. Only
// the fresh capture form is captured (in tr the register section renders — that
// locale-varying content is exactly what the six-cell matrix exists to catch).
void main() {
  for (final cell in sixCells) {
    testWidgets('fresh ${cell.suffix}', (tester) async {
      final fake = FakeProfileRepository();
      addTearDown(fake.dispose);

      await pumpGolden(
        tester,
        const ProfileCaptureScreen(uid: 'uid-1'),
        locale: cell.locale,
        direction: cell.direction,
        overrides: [profileRepositoryProvider.overrideWith((ref) => fake)],
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProfileCaptureScreen),
        matchesGoldenFile(
          goldenFile('profile_capture_screen', 'fresh', cell.suffix),
        ),
      );
    });
  }

  // 130% dynamic-type probe (brandkit max) in each locale's NATURAL direction
  // only: text scale is direction-agnostic, so doubling it across the off-natural
  // cells would add three near-identical goldens with no extra signal.
  for (final cell in naturalCells) {
    testWidgets('fresh_scale130 ${cell.suffix}', (tester) async {
      final fake = FakeProfileRepository();
      addTearDown(fake.dispose);

      await pumpGolden(
        tester,
        const ProfileCaptureScreen(uid: 'uid-1'),
        locale: cell.locale,
        direction: cell.direction,
        textScale: 1.3,
        overrides: [profileRepositoryProvider.overrideWith((ref) => fake)],
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProfileCaptureScreen),
        matchesGoldenFile(
          goldenFile('profile_capture_screen', 'fresh_scale130', cell.suffix),
        ),
      );
    });
  }
}
