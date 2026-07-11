import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/firestore_couple_repository.dart';
import 'package:hayati_app/features/daily_question/domain/couple.dart';
import 'package:hayati_app/features/daily_question/domain/couple_data_exception.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// The @sealed markers below are advisory annotations (not class modifiers) —
// mocktail-mocking them is the established way to unit-test against
// cloud_firestore without a live app (same pattern as
// firestore_solo_answers_repository_test.dart); the real wire path is
// exercised by the emulator rules suite.

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore firestore;
  late MockCollectionReference couples;
  late MockDocumentReference coupleDoc;
  late FirestoreCoupleRepository repository;

  setUp(() {
    firestore = MockFirebaseFirestore();
    couples = MockCollectionReference();
    coupleDoc = MockDocumentReference();
    when(() => firestore.collection('couples')).thenReturn(couples);
    when(() => couples.doc('couple-1')).thenReturn(coupleDoc);
    repository = FirestoreCoupleRepository(firestore: firestore);
  });

  MockDocumentSnapshot snapshotWith(Map<String, dynamic>? data) {
    final snapshot = MockDocumentSnapshot();
    when(snapshot.data).thenReturn(data);
    when(() => snapshot.exists).thenReturn(data != null);
    return snapshot;
  }

  group('watchCouple', () {
    test('maps a document into the domain aggregate', () async {
      when(coupleDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'memberUids': ['uid-1', 'uid-2'],
            'timezone': 'Europe/Istanbul',
          }),
        ),
      );

      expect(
        await repository.watchCouple('couple-1').first,
        const Couple(
          id: 'couple-1',
          memberUids: ['uid-1', 'uid-2'],
          timezone: 'Europe/Istanbul',
        ),
      );
    });

    test('carries the server-owned streak submap into the aggregate '
        '(M3.4)', () async {
      // The wire path threads the couple doc's `streak` field through the DTO
      // (ADR-012) — a doc with no streak already maps to the zero state above,
      // so this pins the present-field case end to end.
      when(coupleDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'memberUids': ['uid-1', 'uid-2'],
            'timezone': 'Europe/Istanbul',
            'streak': {
              'count': 4,
              'lastMutualDate': '20260709',
              'graceTokens': 1,
            },
          }),
        ),
      );

      final couple = await repository.watchCouple('couple-1').first;
      expect(
        couple!.streak,
        const CoupleStreak(
          count: 4,
          lastMutualDate: '20260709',
          graceTokens: 1,
        ),
      );
    });

    test('emits null while the couple doc is absent', () async {
      when(
        coupleDoc.snapshots,
      ).thenAnswer((_) => Stream.value(snapshotWith(null)));

      expect(await repository.watchCouple('couple-1').first, isNull);
    });

    test('maps a transient availability failure to network', () {
      when(coupleDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      expect(
        repository.watchCouple('couple-1').first,
        throwsA(isA<CoupleDataNetworkException>()),
      );
    });

    test('maps a rules denial to permission', () {
      when(coupleDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      expect(
        repository.watchCouple('couple-1').first,
        throwsA(isA<CoupleDataPermissionException>()),
      );
    });

    test('maps an unrecognized code to unknown, preserving the code', () {
      when(coupleDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
          ),
        ),
      );

      expect(
        repository.watchCouple('couple-1').first,
        throwsA(
          isA<CoupleDataUnknownException>().having(
            (e) => e.code,
            'code',
            'failed-precondition',
          ),
        ),
      );
    });

    test('a malformed document surfaces the mapper FormatException through '
        'the taxonomy', () {
      // A junk memberUids field makes coupleFromMap throw; the repository's
      // catch routes it through mapCoupleDataFailure, so a non-Firebase
      // throwable crosses as CoupleDataUnknownException — never raw.
      when(coupleDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'memberUids': ['only-one'],
            'timezone': 'Europe/Istanbul',
          }),
        ),
      );

      expect(
        repository.watchCouple('couple-1').first,
        throwsA(isA<CoupleDataUnknownException>()),
      );
    });
  });
}
