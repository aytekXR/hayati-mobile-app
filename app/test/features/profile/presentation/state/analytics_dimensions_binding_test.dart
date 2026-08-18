import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/analytics/analytics_dimensions.dart';
import 'package:hayati_app/features/profile/domain/content_language_bootstrap.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/state/analytics_dimensions_binding.dart';

/// ADR-057 D3: the dimensions are attached centrally, and two of the three are
/// honestly absent before the profile exists.
void main() {
  RelationshipProfile profileWith({
    required ContentLanguage language,
    required ContentRegister register,
  }) => RelationshipProfile(
    status: RelationshipStatus.married,
    contentLanguage: language,
    register: register,
  );

  group('before profile capture', () {
    test('locale comes from the device and register is NULL', () {
      final dimensions = analyticsDimensionsFor(
        profile: null,
        deviceLanguageCode: 'tr-TR',
      );
      expect(dimensions.locale, AnalyticsLocale.tr);
      expect(
        dimensions.register,
        isNull,
        reason:
            'the user has not made that choice yet — a default would be a '
            'fabricated value',
      );
    });

    test('an unknown device locale falls back to English, not to null', () {
      expect(
        analyticsDimensionsFor(
          profile: null,
          deviceLanguageCode: 'de-DE',
        ).locale,
        AnalyticsLocale.en,
      );
    });
  });

  group('after profile capture', () {
    test('both dimensions come from the profile, over the device locale', () {
      final dimensions = analyticsDimensionsFor(
        profile: profileWith(
          language: ContentLanguage.ar,
          register: ContentRegister.respectful,
        ),
        // Deliberately disagreeing with the profile: the profile always wins,
        // the same precedence contract resolveContentLanguage states.
        deviceLanguageCode: 'en',
      );
      expect(dimensions.locale, AnalyticsLocale.ar);
      expect(dimensions.register, AnalyticsRegister.respectful);
    });

    test('the mapping is total over the full 3x2 product', () {
      for (final language in ContentLanguage.values) {
        for (final register in ContentRegister.values) {
          final dimensions = analyticsDimensionsFor(
            profile: profileWith(language: language, register: register),
            deviceLanguageCode: null,
          );
          expect(dimensions.locale.name, language.name);
          expect(dimensions.register!.name, register.name);
        }
      }
    });
  });

  group('storefront', () {
    test('is null in every case — the app has no storefront source', () {
      // ADR-057 D3 states this slice does not meet §7's storefront obligation.
      // Asserted rather than left implicit, so the day a source appears this
      // test is the thing that says where the promise was.
      expect(
        analyticsDimensionsFor(
          profile: null,
          deviceLanguageCode: 'tr',
        ).storefront,
        isNull,
      );
      expect(
        analyticsDimensionsFor(
          profile: profileWith(
            language: ContentLanguage.tr,
            register: ContentRegister.playful,
          ),
          deviceLanguageCode: 'tr',
        ).storefront,
        isNull,
      );
    });
  });

  group('the analytics locale fallback AGREES with the app-wide one', () {
    // analytics_dimensions.dart's doc comment claims this. If the two ever
    // disagree, an event emitted before profile capture claims a different
    // language from the one the app is actually showing — and the claim in that
    // comment would be false with nothing to catch it.
    test('over every tag either function is expected to classify', () {
      const tags = <String?>[
        'tr',
        'TR',
        'tr-TR',
        'tr_TR',
        'ar',
        'ar_SA',
        'ar-EG',
        'en',
        'en-GB',
        'de',
        'zh-Hant',
        '',
        null,
      ];
      for (final tag in tags) {
        expect(
          analyticsLocaleFor(tag).name,
          bootstrapContentLanguage(deviceLanguageCode: tag).name,
          reason: 'the two locale fallbacks disagree on "$tag"',
        );
      }
    });
  });
}
