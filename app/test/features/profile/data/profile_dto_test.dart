import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/profile/data/profile_dto.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';

void main() {
  const profile = RelationshipProfile(
    status: RelationshipStatus.engaged,
    contentLanguage: ContentLanguage.tr,
    register: ContentRegister.playful,
  );

  group('profileToMap', () {
    test('encodes enums by wire name and nothing else', () {
      expect(profileToMap(profile), {
        'status': 'engaged',
        'contentLanguage': 'tr',
        'register': 'playful',
      });
    });

    test('never emits server-owned fields', () {
      // createdAt / coupleId / fcmTokens are owned by the repository and
      // future milestones (docs/architecture.md §3) — the mapper must not
      // let the client stomp them.
      expect(profileToMap(profile).keys, isNot(contains('createdAt')));
      expect(profileToMap(profile).keys, isNot(contains('coupleId')));
    });
  });

  group('profileFromMap', () {
    test('round-trips what profileToMap wrote', () {
      expect(profileFromMap(profileToMap(profile)), profile);
    });

    test('ignores server-owned and unknown fields', () {
      final data = {
        ...profileToMap(profile),
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1751980000000),
        'coupleId': 'c-1',
        'fcmTokens': ['t1'],
        'someFutureField': 42,
      };

      expect(profileFromMap(data), profile);
    });

    test('rejects unknown enum wire values loudly', () {
      expect(
        () => profileFromMap({
          'status': 'divorced',
          'contentLanguage': 'tr',
          'register': 'playful',
        }),
        throwsFormatException,
      );
    });

    test('rejects missing fields loudly', () {
      expect(
        () => profileFromMap({'status': 'married'}),
        throwsFormatException,
      );
    });

    test('rejects wrongly-typed fields loudly', () {
      expect(
        () => profileFromMap({
          'status': 1,
          'contentLanguage': 'tr',
          'register': 'playful',
        }),
        throwsFormatException,
      );
    });
  });
}
