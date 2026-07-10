import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/firestore_couple_day_repository.dart';
import 'package:hayati_app/features/daily_question/domain/couple_data_exception.dart';
import 'package:hayati_app/features/daily_question/domain/couple_day_assignment.dart';
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
  late MockCollectionReference days;
  late MockDocumentReference dayDoc;
  late FirestoreCoupleDayRepository repository;

  setUp(() {
    firestore = MockFirebaseFirestore();
    couples = MockCollectionReference();
    coupleDoc = MockDocumentReference();
    days = MockCollectionReference();
    dayDoc = MockDocumentReference();
    when(() => firestore.collection('couples')).thenReturn(couples);
    when(() => couples.doc('couple-1')).thenReturn(coupleDoc);
    when(() => coupleDoc.collection('days')).thenReturn(days);
    when(() => days.doc('20260710')).thenReturn(dayDoc);
    repository = FirestoreCoupleDayRepository(firestore: firestore);
  });

  MockDocumentSnapshot snapshotWith(Map<String, dynamic>? data) {
    final snapshot = MockDocumentSnapshot();
    when(snapshot.data).thenReturn(data);
    when(() => snapshot.exists).thenReturn(data != null);
    return snapshot;
  }

  group('watchDay', () {
    test('maps a document into the domain assignment, converting the wire '
        'Timestamp', () async {
      when(dayDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'questionId': 'core_en_042',
            'packId': 'core',
            'packVersion': 3,
            'assignedAt': Timestamp.fromMillisecondsSinceEpoch(1783080000000),
          }),
        ),
      );

      expect(
        await repository.watchDay('couple-1', '20260710').first,
        CoupleDayAssignment(
          questionId: 'core_en_042',
          packId: 'core',
          packVersion: 3,
          assignedAt: DateTime.fromMillisecondsSinceEpoch(1783080000000),
        ),
      );
    });

    test('emits null while no day has been assigned', () async {
      when(
        dayDoc.snapshots,
      ).thenAnswer((_) => Stream.value(snapshotWith(null)));

      expect(await repository.watchDay('couple-1', '20260710').first, isNull);
    });

    test('a pending server stamp (local echo) crosses as a null '
        'assignedAt', () async {
      when(dayDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'questionId': 'core_en_042',
            'packId': 'core',
            'packVersion': 3,
            'assignedAt': null,
          }),
        ),
      );

      final assignment = await repository
          .watchDay('couple-1', '20260710')
          .first;
      expect(assignment?.assignedAt, isNull);
    });

    test('maps a transient availability failure to network', () {
      when(dayDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      expect(
        repository.watchDay('couple-1', '20260710').first,
        throwsA(isA<CoupleDataNetworkException>()),
      );
    });

    test('maps a rules denial to permission', () {
      when(dayDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      expect(
        repository.watchDay('couple-1', '20260710').first,
        throwsA(isA<CoupleDataPermissionException>()),
      );
    });

    test('maps an unrecognized code to unknown, preserving the code', () {
      when(dayDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
          ),
        ),
      );

      expect(
        repository.watchDay('couple-1', '20260710').first,
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
      // A non-int packVersion makes coupleDayAssignmentFromMap throw; the
      // repository's catch routes it through mapCoupleDataFailure, so a
      // non-Firebase throwable crosses as CoupleDataUnknownException.
      when(dayDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'questionId': 'core_en_042',
            'packId': 'core',
            'packVersion': '3',
          }),
        ),
      );

      expect(
        repository.watchDay('couple-1', '20260710').first,
        throwsA(isA<CoupleDataUnknownException>()),
      );
    });
  });
}
