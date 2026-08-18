import 'package:flutter/foundation.dart' show immutable;

/// The `locale` dimension of `architecture.md` §7.
///
/// Analytics owns its own vocabulary rather than importing
/// `ContentLanguage`: nothing under `app/lib/core/` imports `app/lib/features/`
/// (0 of 631 files at the time of writing), and a wire vocabulary that is an
/// alias of a feature enum silently changes meaning when that feature is
/// refactored. The call sites map across; [analyticsLocaleFor] is the fallback
/// for events that fire before a profile exists.
enum AnalyticsLocale { tr, ar, en }

/// The `register` dimension of §7 — the PRODUCT register (`prd.md` F1), which
/// is what §7 means, not the four-valued coach register (that one is derived
/// from `(language, register)` and therefore carries no extra information).
enum AnalyticsRegister { playful, respectful }

/// Maps a device language tag to the [AnalyticsLocale] dimension.
///
/// Deliberately mirrors `bootstrapContentLanguage`, including the normalization
/// (platform sources leak `tr-TR` / `ar_SA`, not just bare subtags) and the
/// English fallback for anything unsupported. The two are asserted to agree in
/// `analytics_dimensions_binding_test.dart`; if they ever disagree, an event
/// emitted before profile capture would claim a different language from the one
/// the app is actually showing.
AnalyticsLocale analyticsLocaleFor(String? deviceLanguageCode) {
  final language = deviceLanguageCode
      ?.split(RegExp('[-_]'))
      .first
      .toLowerCase();
  return switch (language) {
    'tr' => AnalyticsLocale.tr,
    'ar' => AnalyticsLocale.ar,
    _ => AnalyticsLocale.en,
  };
}

/// The §7 dimensions attached to EVERY event, in ONE place (ADR-057 D3) —
/// because a dimension each emitter must remember is a dimension that will be
/// missing from exactly the event someone needs.
///
/// Two of the three are honestly absent for part of the funnel, and that is a
/// recorded decision rather than an oversight:
///
/// * [locale] is **never null**. `install` fires at first launch and `signup`
///   before profile capture, so those carry the device-derived language — which
///   is what a locale dimension means before the user has chosen one.
/// * [register] is **null before profile capture**. A default here would be a
///   fabricated value, and Turkish is the one language where the split is
///   product-meaningful.
/// * [storefront] is **null on every client event today**, and this slice does
///   not meet §7's storefront obligation. `grep -rn storefront app/lib` returns
///   one comment; the supported locales are language-only so the resolved
///   locale's `countryCode` is always null; and RevenueCat — which does know the
///   storefront — is configured only when the dart-define key is present. The
///   server half already carries it (`store`, off the RC event), which is where
///   the dimension was always going to come from (#242).
@immutable
final class AnalyticsDimensions {
  const AnalyticsDimensions({
    required this.locale,
    this.register,
    this.storefront,
  });

  final AnalyticsLocale locale;
  final AnalyticsRegister? register;
  final String? storefront;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsDimensions &&
          other.locale == locale &&
          other.register == register &&
          other.storefront == storefront;

  @override
  int get hashCode => Object.hash(locale, register, storefront);

  @override
  String toString() =>
      'AnalyticsDimensions(locale: ${locale.name}, '
      'register: ${register?.name}, storefront: $storefront)';
}
