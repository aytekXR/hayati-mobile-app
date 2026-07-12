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
      // let the client stomp them, even when the domain object CARRIES a
      // server-read coupleId (M2.3).
      const paired = RelationshipProfile(
        status: RelationshipStatus.engaged,
        contentLanguage: ContentLanguage.tr,
        register: ContentRegister.playful,
        coupleId: 'c-1',
      );
      expect(profileToMap(paired).keys, isNot(contains('createdAt')));
      expect(profileToMap(paired).keys, isNot(contains('coupleId')));
    });
  });

  group('profileFromMap', () {
    test('round-trips what profileToMap wrote', () {
      expect(profileFromMap(profileToMap(profile)), profile);
    });

    test('reads the server-owned coupleId READ-ONLY (M2.3)', () {
      final data = {...profileToMap(profile), 'coupleId': 'couple-1'};

      expect(profileFromMap(data).coupleId, 'couple-1');
      // Absent coupleId → null (a still-solo user).
      expect(profileFromMap(profileToMap(profile)).coupleId, isNull);
    });

    test('rejects a non-string coupleId loudly', () {
      expect(
        () => profileFromMap({...profileToMap(profile), 'coupleId': 42}),
        throwsFormatException,
      );
    });

    test('ignores other server-owned and unknown fields', () {
      final data = {
        ...profileToMap(profile),
        'fcmTokens': ['t1'],
        'someFutureField': 42,
      };

      expect(profileFromMap(data), profile);
    });

    test('reads the boundary-converted createdAt READ-ONLY (M2.4)', () {
      final data = {
        ...profileToMap(profile),
        'createdAt': DateTime.utc(2026, 7, 8),
      };

      expect(profileFromMap(data).createdAt, DateTime.utc(2026, 7, 8));
      // Absent createdAt → null (the pending-serverTimestamp local echo).
      expect(profileFromMap(profileToMap(profile)).createdAt, isNull);
    });

    test('rejects a raw Timestamp createdAt loudly (missed boundary '
        'conversion)', () {
      expect(
        () => profileFromMap({
          ...profileToMap(profile),
          'createdAt': Timestamp.fromMillisecondsSinceEpoch(1751980000000),
        }),
        throwsFormatException,
      );
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

    test('reads notificationPrivacy as an enum-safe boolean (M6.2, D6)', () {
      expect(
        profileFromMap({
          ...profileToMap(profile),
          'notificationPrivacy': 'discreet',
        }).notificationPrivacyDiscreet,
        isTrue,
      );
      // Absent → false; junk → false (never throws — a settings toggle must not
      // brick the profile stream on a stray value).
      expect(
        profileFromMap(profileToMap(profile)).notificationPrivacyDiscreet,
        isFalse,
      );
      expect(
        profileFromMap({
          ...profileToMap(profile),
          'notificationPrivacy': 'nonsense',
        }).notificationPrivacyDiscreet,
        isFalse,
      );
    });

    test('reads the boundary-converted nested coupleEnded.at READ-ONLY '
        '(M6.2, D3)', () {
      final data = {
        ...profileToMap(profile),
        'coupleEnded': {'at': DateTime.utc(2026, 7, 11)},
      };
      expect(profileFromMap(data).coupleEndedAt, DateTime.utc(2026, 7, 11));
      // Absent coupleEnded → null (still paired / never-ended).
      expect(profileFromMap(profileToMap(profile)).coupleEndedAt, isNull);
    });

    test('a raw Timestamp inside coupleEnded.at fails loudly (missed boundary '
        'conversion)', () {
      expect(
        () => profileFromMap({
          ...profileToMap(profile),
          'coupleEnded': {
            'at': Timestamp.fromMillisecondsSinceEpoch(1752000000000),
          },
        }),
        throwsFormatException,
      );
    });

    test('a non-map coupleEnded fails loudly', () {
      expect(
        () => profileFromMap({...profileToMap(profile), 'coupleEnded': 'x'}),
        throwsFormatException,
      );
    });
  });
}
