import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/profile/domain/content_language_bootstrap.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

void main() {
  group('bootstrapContentLanguage', () {
    test('maps a Turkish device locale to Turkish content', () {
      expect(
        bootstrapContentLanguage(deviceLanguageCode: 'tr'),
        ContentLanguage.tr,
      );
    });

    test('maps an Arabic device locale to Arabic content', () {
      expect(
        bootstrapContentLanguage(deviceLanguageCode: 'ar'),
        ContentLanguage.ar,
      );
    });

    test('maps an English device locale to English content', () {
      expect(
        bootstrapContentLanguage(deviceLanguageCode: 'en'),
        ContentLanguage.en,
      );
    });

    test('falls back to English for unsupported languages', () {
      expect(
        bootstrapContentLanguage(deviceLanguageCode: 'de'),
        ContentLanguage.en,
      );
    });

    test('falls back to English when the device locale is unknown', () {
      expect(
        bootstrapContentLanguage(deviceLanguageCode: null),
        ContentLanguage.en,
      );
    });

    test('is defensive about casing and region subtags', () {
      expect(
        bootstrapContentLanguage(deviceLanguageCode: 'TR'),
        ContentLanguage.tr,
      );
      expect(
        bootstrapContentLanguage(deviceLanguageCode: 'ar_SA'),
        ContentLanguage.ar,
      );
      expect(
        bootstrapContentLanguage(deviceLanguageCode: 'tr-TR'),
        ContentLanguage.tr,
      );
    });
  });

  group('resolveContentLanguage', () {
    const arabicProfile = RelationshipProfile(
      status: RelationshipStatus.dating,
      contentLanguage: ContentLanguage.ar,
      register: ContentRegister.respectful,
    );

    test('a saved profile override always beats the device locale', () {
      expect(
        resolveContentLanguage(
          profile: arabicProfile,
          deviceLanguageCode: 'tr',
        ),
        ContentLanguage.ar,
      );
    });

    test('without a profile the device bootstrap decides', () {
      expect(
        resolveContentLanguage(profile: null, deviceLanguageCode: 'tr'),
        ContentLanguage.tr,
      );
    });

    test('without a profile or a device locale, English wins', () {
      expect(
        resolveContentLanguage(profile: null, deviceLanguageCode: null),
        ContentLanguage.en,
      );
    });
  });
}
