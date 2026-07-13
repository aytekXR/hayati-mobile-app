/// The two in-app legal documents (ADR-023 Decision 5). Each maps to a bundled
/// asset base name under `assets/legal/`; the per-locale file is resolved by
/// [legalAssetPath] with an EN fallback.
enum LegalDocument {
  privacyPolicy('privacy-policy'),
  terms('terms');

  const LegalDocument(this.assetBase);

  /// The asset filename stem — `assets/legal/<assetBase>.<locale>.md`.
  final String assetBase;
}

/// The bundled markdown asset path for [document] in [languageCode], falling
/// back to English for any locale we do not ship (ADR-023 D5: one document per
/// locale, EN fallback). Pure so the drift test and `shippedLegalBundle()` share
/// the exact path convention the screen loads.
String legalAssetPath(LegalDocument document, String languageCode) {
  const shipped = {'tr', 'ar', 'en'};
  final locale = shipped.contains(languageCode) ? languageCode : 'en';
  return 'assets/legal/${document.assetBase}.$locale.md';
}
