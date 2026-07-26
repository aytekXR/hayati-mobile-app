import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/widgets/seed_vessel.dart';

import '../../support/golden/golden_harness.dart';

/// The seed vessel's product states (creative-assets §6.1 / product spec):
/// empty · first-seed · 7-day · 30-day (rising fill past 14 individual seeds)
/// · mercy-day (Sage leaf) · streak-safe glint. Captured at hero size (96dp)
/// on the Night canvas so every Nightbloom layer (Night Raised body, Veil
/// rim, Clay foot, pomegranate seed gradient, Sage accents) is eyeball-able.
///
/// The glyph is text-free and drawn symmetric, so the matrix is en.ltr plus
/// ONE rtl probe (certifying the drawn-RTL-neutral claim) rather than the
/// six-cell contract reserved for text-bearing surfaces — the strip that
/// hosts it takes the full matrix via the paired-home goldens.
void main() {
  Future<void> pumpVessel(
    WidgetTester tester, {
    required int seedCount,
    bool streakSafe = false,
    bool mercyDayUsed = false,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await pumpGolden(
      tester,
      Scaffold(
        body: Center(
          child: SeedVessel(
            seedCount: seedCount,
            streakSafe: streakSafe,
            mercyDayUsed: mercyDayUsed,
            width: 96,
          ),
        ),
      ),
      locale: const Locale('en'),
      direction: direction,
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String state, String cell) =>
      expectLater(
        find.byType(SeedVessel),
        matchesGoldenFile(goldenFile('seed_vessel', state, cell)),
      );

  testWidgets('empty — the bowl awaits the first mutual day', (tester) async {
    await pumpVessel(tester, seedCount: 0);
    await capture(tester, 'empty', 'en.ltr');
  });

  testWidgets('first seed — day 1, no fanfare', (tester) async {
    await pumpVessel(tester, seedCount: 1);
    await capture(tester, 'first_seed', 'en.ltr');
  });

  testWidgets('seven seeds with the streak-safe Sage glint on the topmost', (
    tester,
  ) async {
    await pumpVessel(tester, seedCount: 7, streakSafe: true);
    await capture(tester, 'seven', 'en.ltr');
  });

  testWidgets('thirty seeds — past 14 the seeds become a rising fill', (
    tester,
  ) async {
    await pumpVessel(tester, seedCount: 30);
    await capture(tester, 'thirty', 'en.ltr');
  });

  testWidgets('mercy day — the Sage leaf rests over the seeds', (tester) async {
    await pumpVessel(tester, seedCount: 7, mercyDayUsed: true);
    await capture(tester, 'mercy', 'en.ltr');
  });

  testWidgets('RTL probe — drawn symmetric, certified direction-neutral '
      '(byte-comparable against seven en.ltr by eye)', (tester) async {
    await pumpVessel(
      tester,
      seedCount: 7,
      streakSafe: true,
      direction: TextDirection.rtl,
    );
    await capture(tester, 'seven', 'en.rtl');
  });

  testWidgets('the glyph is decorative: excluded from semantics (the strip '
      'text carries meaning)', (tester) async {
    await pumpVessel(tester, seedCount: 7);
    expect(
      find.ancestor(
        of: find.byType(CustomPaint).last,
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });
}
