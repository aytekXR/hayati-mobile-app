import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/presentation/couple_ended_notice_screen.dart';

import '../../../support/golden/golden_harness.dart';

/// B's morning-after notice across the matrix (ADR-019 D3). The build is pure UI
/// (the flag store + reactive provider are read only on the Continue tap), so the
/// golden needs no overrides. A fixed `coupleEndedAt` keeps it deterministic.
void main() {
  final at = DateTime.fromMillisecondsSinceEpoch(1752000000000);

  Future<void> pump(
    WidgetTester tester,
    GoldenCell cell, {
    double textScale = 1.0,
  }) async {
    await pumpGolden(
      tester,
      CoupleEndedNoticeScreen(uid: 'uid-1', coupleEndedAt: at),
      locale: cell.locale,
      direction: cell.direction,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  for (final cell in sixCells) {
    testWidgets('notice ${cell.suffix}', (tester) async {
      await pump(tester, cell);
      await expectLater(
        find.byType(CoupleEndedNoticeScreen),
        matchesGoldenFile(
          goldenFile('couple_ended_notice_screen', 'notice', cell.suffix),
        ),
      );
    });
  }

  for (final cell in naturalCells) {
    testWidgets('notice scale130 ${cell.suffix}', (tester) async {
      await pump(tester, cell, textScale: 1.3);
      await expectLater(
        find.byType(CoupleEndedNoticeScreen),
        matchesGoldenFile(
          goldenFile(
            'couple_ended_notice_screen',
            'notice.scale130',
            cell.suffix,
          ),
        ),
      );
    });
  }
}
