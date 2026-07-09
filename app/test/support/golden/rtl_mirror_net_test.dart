import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

// Proves the golden net can actually SEE an RTL regression — that the goldens
// encode direction-mirroring, not just any render. The probe is a directional
// arrow (Icons.arrow_back auto-mirrors via matchTextDirection) beside a short
// label; the Row also reverses under RTL.
const _probeKey = Key('rtl-probe');
const _mirrored = 'goldens/probe/back_arrow.rtl.png';
const _unmirrored = 'goldens/probe/back_arrow.unmirrored.png';

Widget _probe({TextDirection? iconDirection}) => Scaffold(
  key: _probeKey,
  body: Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_back, size: 64, textDirection: iconDirection),
        const SizedBox(width: 12),
        const Text('back'),
      ],
    ),
  ),
);

void main() {
  // Positive: the arrow auto-mirrors under RTL → recorded as the RTL golden.
  testWidgets('a directional icon mirrors under RTL', (tester) async {
    await pumpGolden(
      tester,
      _probe(),
      locale: const Locale('ar'),
      direction: TextDirection.rtl,
    );
    await tester.pumpAndSettle();

    await expectLater(find.byKey(_probeKey), matchesGoldenFile(_mirrored));
  });

  // The SAME probe with the icon forced un-mirrored (explicit LTR) under the RTL
  // app → recorded as a SEPARATE golden.
  testWidgets('the same arrow forced un-mirrored under RTL', (tester) async {
    await pumpGolden(
      tester,
      _probe(iconDirection: TextDirection.ltr),
      locale: const Locale('ar'),
      direction: TextDirection.rtl,
    );
    await tester.pumpAndSettle();

    await expectLater(find.byKey(_probeKey), matchesGoldenFile(_unmirrored));
  });

  // The net. If the goldens capture direction-mirroring, the mirrored and
  // un-mirrored PNGs MUST differ. Flutter's PNG encoder is deterministic, so
  // equal pixels would yield byte-identical files — identical bytes here would
  // mean a real RTL regression could slip past every golden unseen.
  //
  // A file byte-compare (rather than an intentional matchesGoldenFile mismatch)
  // is used deliberately: an expected golden mismatch reports its TestFailure
  // through the async error zone (escaping try/catch), and capturing pixels via
  // RenderRepaintBoundary.toImage hangs in the headless test rasterizer. This
  // comparison needs neither — and it still fails loudly if the arrow ever
  // stops mirroring.
  test('the RTL golden differs from the un-mirrored render', () async {
    final basedir = (goldenFileComparator as LocalFileComparator).basedir;
    final mirrored = await File.fromUri(
      basedir.resolve(_mirrored),
    ).readAsBytes();
    final unmirrored = await File.fromUri(
      basedir.resolve(_unmirrored),
    ).readAsBytes();

    expect(mirrored, isNot(equals(unmirrored)));
  });
}
