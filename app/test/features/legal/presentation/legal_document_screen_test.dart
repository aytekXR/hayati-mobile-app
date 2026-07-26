import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/domain/legal_document.dart';
import 'package:hayati_app/features/legal/presentation/legal_document_screen.dart';

import '../../../support/localized_app.dart';
import '../../../support/static_asset_bundle.dart';

/// A line from the SHIPPED privacy-policy asset, pinned deliberately as a
/// literal: it is what proves the injected bundle delivered the real document
/// rather than a placeholder the seam invented. Two tests use it.
///
/// It is therefore a FOURTH carrier of the legal version string, and it is NOT
/// covered by `legal_version_sentinel_test.dart`'s three-way pin (that guards
/// the app const, the Functions const and `docs/legal/README.md`). A version
/// bump reddens this file separately — which is how S042 found it. The bump
/// procedure in `docs/legal/README.md` now names it so the next bump does not
/// rediscover it the hard way.
const shippedPolicyVersionLine = 'Version 2. Effective 26 July 2026.';

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
      expect(find.text(shippedPolicyVersionLine), findsOneWidget);
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

    expect(find.text(shippedPolicyVersionLine), findsOneWidget);
  });
}
