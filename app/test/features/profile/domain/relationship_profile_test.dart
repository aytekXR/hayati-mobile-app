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

    test('coupleId participates in equality and toString', () {
      const paired = RelationshipProfile(
        status: RelationshipStatus.married,
        contentLanguage: ContentLanguage.tr,
        register: ContentRegister.playful,
        coupleId: 'couple-1',
      );
      expect(paired, isNot(profile)); // profile has coupleId null
      expect(paired.hashCode, isNot(profile.hashCode));
      expect(paired.toString(), contains('couple-1'));
    });

    test(
      'copyWith preserves the server-owned coupleId (no param to clear it)',
      () {
        const paired = RelationshipProfile(
          status: RelationshipStatus.married,
          contentLanguage: ContentLanguage.tr,
          register: ContentRegister.playful,
          coupleId: 'couple-1',
        );

        // A client edit of a captured field must carry the pairing through.
        final edited = paired.copyWith(status: RelationshipStatus.engaged);
        expect(edited.coupleId, 'couple-1');
        expect(edited.status, RelationshipStatus.engaged);
      },
    );

    test('createdAt participates in equality and toString (M2.4)', () {
      final stamped = RelationshipProfile(
        status: RelationshipStatus.married,
        contentLanguage: ContentLanguage.tr,
        register: ContentRegister.playful,
        createdAt: DateTime.utc(2026, 7, 8),
      );
      expect(stamped, isNot(profile)); // profile has createdAt null
      expect(stamped.hashCode, isNot(profile.hashCode));
      expect(stamped.toString(), contains('2026-07-08'));
    });

    test('copyWith preserves the server-owned createdAt '
        '(no param to move it)', () {
      final stamped = RelationshipProfile(
        status: RelationshipStatus.married,
        contentLanguage: ContentLanguage.tr,
        register: ContentRegister.playful,
        createdAt: DateTime.utc(2026, 7, 8),
      );

      // The solo day-N anchor must survive a client profile edit.
      final edited = stamped.copyWith(register: ContentRegister.respectful);
      expect(edited.createdAt, DateTime.utc(2026, 7, 8));
      expect(edited.register, ContentRegister.respectful);
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
