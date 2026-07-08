import 'relationship_profile.dart';

/// Locale bootstrapping (docs/implementation-plan.md M1): the device locale
/// suggests a content language until the profile owns the choice.
///
/// Pure Dart by design — callers pass `Locale.languageCode` (or the raw
/// platform tag) as a string so the domain stays free of Flutter imports.
ContentLanguage bootstrapContentLanguage({String? deviceLanguageCode}) {
  // Locale.languageCode is a bare lowercase subtag, but platform sources can
  // leak tags like 'tr-TR'/'ar_SA' — normalize instead of misclassifying.
  final language = deviceLanguageCode
      ?.split(RegExp('[-_]'))
      .first
      .toLowerCase();
  return switch (language) {
    'tr' => ContentLanguage.tr,
    'ar' => ContentLanguage.ar,
    // English is the deliberate fallback for unsupported/unknown locales:
    // it is the only pack every storefront can read (docs/prd.md).
    _ => ContentLanguage.en,
  };
}

/// Precedence contract: a saved profile override ALWAYS beats the device
/// locale; the bootstrap only fills the gap before the profile exists.
ContentLanguage resolveContentLanguage({
  required RelationshipProfile? profile,
  required String? deviceLanguageCode,
}) =>
    profile?.contentLanguage ??
    bootstrapContentLanguage(deviceLanguageCode: deviceLanguageCode);
