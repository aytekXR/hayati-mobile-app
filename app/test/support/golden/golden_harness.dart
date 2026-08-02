import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
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

/// The env var that re-sizes the golden surface, as `WIDTHxHEIGHT@DPR`.
///
/// UNSET IS THE ONLY THING CI EVER SEES: every committed golden is 390×844 @1x
/// and stays byte-identical. The override exists so the App Store screenshot
/// lane can render the SAME states, from the SAME fakes, at 1290×2796 @3 —
/// re-deriving those states in a parallel file would let the marketing images
/// and the tested product drift apart, which is the one thing a screenshot must
/// not do.
const goldenSurfaceVar = 'APPSTORE_SCREENSHOT_SURFACE';

/// Key on the [RepaintBoundary] wrapping everything [pumpGolden] pumps.
///
/// Always present, including on the 1x golden path, so the two paths render the
/// identical widget tree — a boundary that existed only under the screenshot
/// env would make the store assets a render of something the goldens never
/// prove. It changes layer structure, not layout or paint.
const goldenSurfaceKey = ValueKey<String>('golden-surface');

/// Resolves the golden surface from [env] (defaults to the process env).
///
/// THROWS on a malformed value rather than falling back to the default. A typo
/// that silently produced 390×844 would hand the founder a folder of
/// plausible-looking PNGs that App Store Connect rejects at upload, hours
/// later, with no clue pointing back to the typo — the failure has to happen
/// here, where the cause is on screen.
({Size size, double dpr}) goldenSurface([Map<String, String>? env]) {
  final raw = (env ?? Platform.environment)[goldenSurfaceVar]?.trim();
  if (raw == null || raw.isEmpty) {
    return (size: const Size(390, 844), dpr: 1.0);
  }
  final parsed = RegExp(r'^(\d+)x(\d+)@(\d+(?:\.\d+)?)$').firstMatch(raw);
  if (parsed == null) {
    throw ArgumentError.value(
      raw,
      goldenSurfaceVar,
      'must look like WIDTHxHEIGHT@DPR, e.g. 1290x2796@3.0',
    );
  }
  return (
    size: Size(double.parse(parsed.group(1)!), double.parse(parsed.group(2)!)),
    dpr: double.parse(parsed.group(3)!),
  );
}

/// Pumps [home] inside the branded app on a fixed 390×844 @1x surface for a
/// deterministic golden — or on the surface [goldenSurfaceVar] names.
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
  final surface = goldenSurface();
  tester.view.physicalSize = surface.size;
  tester.view.devicePixelRatio = surface.dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: goldenSurfaceKey,
      child: ProviderScope(
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
    ),
  );
}

/// Writes the pumped surface to [path] as a PNG at the surface's DPR.
///
/// WHY THIS EXISTS RATHER THAN `matchesGoldenFile`. Measured: with the view at
/// 1290×2796 @3, `matchesGoldenFile` writes a **430×932** file. Its capture is
/// at the LOGICAL size and ignores `devicePixelRatio` entirely — correct for a
/// golden (a diff wants layout, not pixels) and useless for a store asset,
/// which App Store Connect rejects unless it is exactly 1290×2796. So the
/// screenshot lane captures the boundary itself and passes the DPR explicitly.
///
/// `runAsync` is required, not decorative: `toImage` hands work to the engine,
/// and the fake-async zone a widget test runs in never lets that future
/// complete — without it this hangs until the test times out.
Future<void> writeSurfacePng(WidgetTester tester, String path) async {
  final surface = goldenSurface();
  final boundary =
      tester.renderObject(find.byKey(goldenSurfaceKey))
          as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: surface.dpr);
    final data = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
}
