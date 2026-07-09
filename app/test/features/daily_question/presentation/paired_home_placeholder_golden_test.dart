import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_placeholder.dart';

import '../../../support/golden/golden_harness.dart';

// The M3 daily-question slot: a static branded "you're paired" surface, so the
// full six-cell tr/ar/en × ltr/rtl matrix applies (no transient frames).
void main() {
  for (final cell in sixCells) {
    testWidgets('paired ${cell.suffix}', (tester) async {
      await pumpGolden(
        tester,
        const PairedHomePlaceholder(),
        locale: cell.locale,
        direction: cell.direction,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PairedHomePlaceholder),
        matchesGoldenFile(
          goldenFile('paired_home_placeholder', 'paired', cell.suffix),
        ),
      );
    });
  }
}
