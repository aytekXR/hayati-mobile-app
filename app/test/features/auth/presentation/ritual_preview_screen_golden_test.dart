import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/presentation/ritual_preview_screen.dart';

import '../../../support/golden/golden_harness.dart';
import '../../../support/localized_app.dart';

// The three preview cards, reached exactly as a user reaches them (Continue
// taps), captured per six-cell matrix. The screen reads no providers at
// build time — the flag store is only touched on completion — so no
// overrides are needed. The 130% probe covers card 1 in each natural
// direction (the longest headline set).
void main() {
  Future<void> advance(WidgetTester tester, GoldenCell cell, int taps) async {
    final l10n = l10nFor(cell.locale);
    for (var i = 0; i < taps; i++) {
      await tester.tap(find.text(l10n.continueAction));
      await tester.pumpAndSettle();
    }
  }

  for (var card = 1; card <= 3; card++) {
    for (final cell in sixCells) {
      testWidgets('card$card ${cell.suffix}', (tester) async {
        await pumpGolden(
          tester,
          const RitualPreviewScreen(),
          locale: cell.locale,
          direction: cell.direction,
        );
        await tester.pumpAndSettle();
        await advance(tester, cell, card - 1);

        await expectLater(
          find.byType(RitualPreviewScreen),
          matchesGoldenFile(
            goldenFile('ritual_preview_screen', 'card$card', cell.suffix),
          ),
        );
      });
    }
  }

  for (final cell in naturalCells) {
    testWidgets('card1_scale130 ${cell.suffix}', (tester) async {
      await pumpGolden(
        tester,
        const RitualPreviewScreen(),
        locale: cell.locale,
        direction: cell.direction,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(RitualPreviewScreen),
        matchesGoldenFile(
          goldenFile('ritual_preview_screen', 'card1_scale130', cell.suffix),
        ),
      );
    });
  }
}
