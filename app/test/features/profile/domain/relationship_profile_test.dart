import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

void main() {
  group('RelationshipProfile', () {
    const profile = RelationshipProfile(
      status: RelationshipStatus.married,
      contentLanguage: ContentLanguage.tr,
      register: ContentRegister.playful,
    );

    test('value equality is field-based', () {
      expect(
        profile,
        const RelationshipProfile(
          status: RelationshipStatus.married,
          contentLanguage: ContentLanguage.tr,
          register: ContentRegister.playful,
        ),
      );
      expect(
        profile.hashCode,
        const RelationshipProfile(
          status: RelationshipStatus.married,
          contentLanguage: ContentLanguage.tr,
          register: ContentRegister.playful,
        ).hashCode,
      );
    });

    test('profiles with any differing field are unequal', () {
      expect(
        profile,
        isNot(profile.copyWith(status: RelationshipStatus.dating)),
      );
      expect(
        profile,
        isNot(profile.copyWith(contentLanguage: ContentLanguage.ar)),
      );
      expect(
        profile,
        isNot(profile.copyWith(register: ContentRegister.respectful)),
      );
    });

    test('copyWith replaces only the given fields', () {
      final updated = profile.copyWith(contentLanguage: ContentLanguage.en);

      expect(updated.contentLanguage, ContentLanguage.en);
      expect(updated.status, RelationshipStatus.married);
      expect(updated.register, ContentRegister.playful);
    });

    test('copyWith with no arguments returns an equal profile', () {
      expect(profile.copyWith(), profile);
    });

    test('captures the PRD F1 option sets exactly', () {
      // docs/prd.md F1: status dating/engaged/married; language tr/ar/en;
      // register playful/respectful. A new enum value must be a deliberate
      // product decision, so pin the sets.
      expect(RelationshipStatus.values, hasLength(3));
      expect(ContentLanguage.values, hasLength(3));
      expect(ContentRegister.values, hasLength(2));
    });
  });
}
