import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/domain/legal_document.dart';
import 'package:hayati_app/features/legal/presentation/legal_document_screen.dart';

import '../../../support/localized_app.dart';
import '../../../support/static_asset_bundle.dart';

void main() {
  final en = l10nFor(const Locale('en'));

  testWidgets(
    'renders the resolved-locale document through the injected bundle',
    (tester) async {
      await tester.pumpWidget(
        localizedApp(
          LegalDocumentScreen(
            document: LegalDocument.privacyPolicy,
            bundle: shippedLegalBundle(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App-bar title from ARB; the `#` title + a known body line from the doc.
      expect(find.text(en.legalPrivacyTitle), findsWidgets);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Version 1. Effective 13 July 2026.'), findsOneWidget);
    },
  );

  testWidgets('the terms document renders through the seam', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        LegalDocumentScreen(
          document: LegalDocument.terms,
          bundle: shippedLegalBundle(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms of Use'), findsWidgets);
  });

  testWidgets('a missing asset shows the honest load error (never wedges)', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        LegalDocumentScreen(
          document: LegalDocument.privacyPolicy,
          bundle: StaticAssetBundle(const {}), // no assets → load throws
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.legalDocumentError), findsOneWidget);
  });

  testWidgets('an unshipped locale falls back to the English document', (
    tester,
  ) async {
    // 'de' is not a shipped locale; the resolved app locale is EN (preferred),
    // so the EN asset path is loaded from the bundle.
    await tester.pumpWidget(
      localizedApp(
        LegalDocumentScreen(
          document: LegalDocument.privacyPolicy,
          bundle: shippedLegalBundle(),
        ),
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 1. Effective 13 July 2026.'), findsOneWidget);
  });
}
