import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/design_system/hayati_theme.dart';
import 'package:hayati_app/core/l10n/gen/app_localizations.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation (a
// direct dependency) exposes it — same seam localized_app.dart uses.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

/// One matrix cell: a locale paired with a forced text direction plus the file
/// suffix its golden is named with. The direction is decoupled from the
/// locale's natural direction on purpose (see [sixCells]).
class GoldenCell {
  const GoldenCell(this.locale, this.direction, this.suffix);

  final Locale locale;
  final TextDirection direction;
  final String suffix;
}

/// The six-cell contract: every state is captured in tr/ar/en × ltr/rtl. Each
/// locale is rendered in BOTH directions — the off-natural cells (e.g. ar.ltr,
/// en.rtl) prove the layout mirrors on direction alone, independent of which
/// script the copy happens to be.
const sixCells = <GoldenCell>[
  GoldenCell(Locale('tr'), TextDirection.ltr, 'tr.ltr'),
  GoldenCell(Locale('tr'), TextDirection.rtl, 'tr.rtl'),
  GoldenCell(Locale('ar'), TextDirection.ltr, 'ar.ltr'),
  GoldenCell(Locale('ar'), TextDirection.rtl, 'ar.rtl'),
  GoldenCell(Locale('en'), TextDirection.ltr, 'en.ltr'),
  GoldenCell(Locale('en'), TextDirection.rtl, 'en.rtl'),
];

/// The three cells rendered in each locale's NATURAL direction (ar→rtl, others
/// →ltr). Used for pure text-scale probes where doubling into the off-natural
/// direction adds no signal.
const naturalCells = <GoldenCell>[
  GoldenCell(Locale('tr'), TextDirection.ltr, 'tr.ltr'),
  GoldenCell(Locale('ar'), TextDirection.rtl, 'ar.rtl'),
  GoldenCell(Locale('en'), TextDirection.ltr, 'en.ltr'),
];

/// Golden key for a [screen]/[state]/[cell], resolved relative to the calling
/// test file's directory by [matchesGoldenFile].
String goldenFile(String screen, String state, String cell) =>
    'goldens/$screen/$state.$cell.png';

/// Pumps [home] inside the branded app on a fixed 390×844 @1x surface for a
/// deterministic golden.
///
/// The [Directionality] override lives INSIDE the MaterialApp so the cell's
/// [direction] wins regardless of [locale] — that decoupling is the six-cell
/// contract. TextDirection literals are fine here: rtl_lint scans app/lib only.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget home, {
  required Locale locale,
  required TextDirection direction,
  List<Override> overrides = const [],
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: hayatiTheme(languageCode: locale.languageCode),
        home: Builder(
          builder: (context) {
            final directed = Directionality(
              textDirection: direction,
              child: home,
            );
            if (textScale == 1.0) return directed;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: directed,
            );
          },
        ),
      ),
    ),
  );
}
