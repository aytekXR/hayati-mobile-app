import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/domain/legal_document.dart';
import 'package:hayati_app/features/legal/presentation/legal_document_screen.dart';

import '../../../support/golden/golden_harness.dart';
import '../../../support/static_asset_bundle.dart';

/// The one-document renderer across each locale's natural direction (ADR-023
/// D5), loaded through the injected off-disk bundle seam so a real `rootBundle`
/// load never wedges `pumpAndSettle`. The privacy policy is the representative
/// document (title + sections + bullets + prose exercise every renderer path).
void main() {
  for (final cell in naturalCells) {
    testWidgets('privacy_policy ${cell.suffix}', (tester) async {
      await pumpGolden(
        tester,
        LegalDocumentScreen(
          document: LegalDocument.privacyPolicy,
          bundle: shippedLegalBundle(),
        ),
        locale: cell.locale,
        direction: cell.direction,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LegalDocumentScreen),
        matchesGoldenFile(
          goldenFile('legal_document_screen', 'privacy_policy', cell.suffix),
        ),
      );
    });
  }
}
