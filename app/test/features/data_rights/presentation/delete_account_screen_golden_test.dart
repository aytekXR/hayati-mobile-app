import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/presentation/delete_account_screen.dart';

import '../../../support/golden/golden_harness.dart';

/// The delete-account screen across the matrix (ADR-019 D7). The build is pure UI
/// (the lock/auth/data-rights seams are read only on the confirm tap), so the
/// golden needs no overrides.
void main() {
  Future<void> pump(
    WidgetTester tester,
    GoldenCell cell, {
    double textScale = 1.0,
  }) async {
    await pumpGolden(
      tester,
      const DeleteAccountScreen(),
      locale: cell.locale,
      direction: cell.direction,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  for (final cell in sixCells) {
    testWidgets('default ${cell.suffix}', (tester) async {
      await pump(tester, cell);
      await expectLater(
        find.byType(DeleteAccountScreen),
        matchesGoldenFile(
          goldenFile('delete_account_screen', 'default', cell.suffix),
        ),
      );
    });
  }

  for (final cell in naturalCells) {
    testWidgets('default scale130 ${cell.suffix}', (tester) async {
      await pump(tester, cell, textScale: 1.3);
      await expectLater(
        find.byType(DeleteAccountScreen),
        matchesGoldenFile(
          goldenFile('delete_account_screen', 'default.scale130', cell.suffix),
        ),
      );
    });
  }
}
