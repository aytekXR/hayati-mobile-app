import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/profile/presentation/name_capture_screen.dart';

import '../../../support/golden/golden_harness.dart';

// Only the fresh (empty, phone sign-up) form is captured: the pre-filled
// variant differs by field text alone (covered behaviourally), and the save
// spinner is indeterminate. The screen reads no providers at build time, so
// no overrides are needed.
void main() {
  const phoneUser = AuthUser(uid: 'uid-1');

  for (final cell in sixCells) {
    testWidgets('fresh ${cell.suffix}', (tester) async {
      await pumpGolden(
        tester,
        const NameCaptureScreen(user: phoneUser),
        locale: cell.locale,
        direction: cell.direction,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(NameCaptureScreen),
        matchesGoldenFile(
          goldenFile('name_capture_screen', 'fresh', cell.suffix),
        ),
      );
    });
  }

  // 130% dynamic-type probe (brandkit max) in each locale's NATURAL direction
  // only — the profile-capture precedent.
  for (final cell in naturalCells) {
    testWidgets('fresh_scale130 ${cell.suffix}', (tester) async {
      await pumpGolden(
        tester,
        const NameCaptureScreen(user: phoneUser),
        locale: cell.locale,
        direction: cell.direction,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(NameCaptureScreen),
        matchesGoldenFile(
          goldenFile('name_capture_screen', 'fresh_scale130', cell.suffix),
        ),
      );
    });
  }
}
