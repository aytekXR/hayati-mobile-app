import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/legal/domain/legal_document.dart';

/// Byte-equality drift test (ADR-023 Decision 5): the six documents authored in
/// `docs/legal/` must be byte-identical to their bundled copies in
/// `app/assets/legal/`. Both trees are read off disk from the `app/` test cwd
/// (the shipped-packs-off-disk precedent). Drift fails RED — the content-pack
/// `--sync` tool is deliberately NOT extended; six static files need a red CI on
/// drift, not a tool.
void main() {
  for (final document in LegalDocument.values) {
    for (final locale in const ['tr', 'ar', 'en']) {
      test('${document.assetBase}.$locale.md is byte-identical across trees', () {
        final assetPath = legalAssetPath(document, locale);
        final docsPath = '../docs/legal/${document.assetBase}.$locale.md';

        final asset = File(assetPath);
        final docs = File(docsPath);
        expect(asset.existsSync(), isTrue, reason: 'missing $assetPath');
        expect(docs.existsSync(), isTrue, reason: 'missing $docsPath');

        expect(
          asset.readAsBytesSync(),
          docs.readAsBytesSync(),
          reason:
              '$assetPath drifted from $docsPath — re-sync the bundled copy in '
              'the same diff (docs/legal/README.md bump procedure).',
        );
      });
    }
  }
}
