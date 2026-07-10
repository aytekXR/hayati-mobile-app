import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/couple_failure_mapper.dart';
import 'package:hayati_app/features/daily_question/data/firestore_couple_answers_repository.dart';
import 'package:hayati_app/features/daily_question/domain/couple_answer.dart';
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
  late MockCollectionReference days;
  late MockDocumentReference dayDoc;
  late MockCollectionReference answers;
  late MockDocumentReference answerDoc;
  late FirestoreCoupleAnswersRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    firestore = MockFirebaseFirestore();
    couples = MockCollectionReference();
    coupleDoc = MockDocumentReference();
    days = MockCollectionReference();
    dayDoc = MockDocumentReference();
    answers = MockCollectionReference();
    answerDoc = MockDocumentReference();
    when(() => firestore.collection('couples')).thenReturn(couples);
    when(() => couples.doc('couple-1')).thenReturn(coupleDoc);
    when(() => coupleDoc.collection('days')).thenReturn(days);
    when(() => days.doc('20260710')).thenReturn(dayDoc);
    when(() => dayDoc.collection('answers')).thenReturn(answers);
    when(() => answers.doc('uid-1')).thenReturn(answerDoc);
    repository = FirestoreCoupleAnswersRepository(firestore: firestore);
  });

  MockDocumentSnapshot snapshotWith(Map<String, dynamic>? data) {
    final snapshot = MockDocumentSnapshot();
    when(snapshot.data).thenReturn(data);
    when(() => snapshot.exists).thenReturn(data != null);
    return snapshot;
  }

  group('watchAnswer', () {
    test('maps a document into the domain entity, converting the wire '
        'Timestamp', () async {
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'questionId': 'core_en_042',
            'text': 'You, always.',
            'answeredAt': Timestamp.fromMillisecondsSinceEpoch(1783080000000),
          }),
        ),
      );

      expect(
        await repository.watchAnswer('couple-1', '20260710', 'uid-1').first,
        CoupleAnswer(
          questionId: 'core_en_042',
          text: 'You, always.',
          answeredAt: DateTime.fromMillisecondsSinceEpoch(1783080000000),
        ),
      );
    });

    test('emits null while the answer doc is absent', () async {
      when(
        answerDoc.snapshots,
      ).thenAnswer((_) => Stream.value(snapshotWith(null)));

      expect(
        await repository.watchAnswer('couple-1', '20260710', 'uid-1').first,
        isNull,
      );
    });

    test('a pending server stamp (local echo) crosses as a null answeredAt '
        '— the exact signal the partner-slot gate waits out', () async {
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'questionId': 'core_en_042',
            'text': 'You, always.',
            'answeredAt': null,
          }),
        ),
      );

      final answer = await repository
          .watchAnswer('couple-1', '20260710', 'uid-1')
          .first;
      expect(answer?.answeredAt, isNull);
    });

    test('maps a transient availability failure to network', () {
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      expect(
        repository.watchAnswer('couple-1', '20260710', 'uid-1').first,
        throwsA(isA<CoupleDataNetworkException>()),
      );
    });

    test('maps a rules denial to permission — the pre-reveal locked '
        'signal', () {
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      expect(
        repository.watchAnswer('couple-1', '20260710', 'uid-1').first,
        throwsA(isA<CoupleDataPermissionException>()),
      );
    });

    test('maps an unrecognized code to unknown, preserving the code', () {
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
          ),
        ),
      );

      expect(
        repository.watchAnswer('couple-1', '20260710', 'uid-1').first,
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
      // A non-string text field makes coupleAnswerFromMap throw; the
      // repository's catch routes it through mapCoupleDataFailure, so a
      // non-Firebase throwable crosses as CoupleDataUnknownException.
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({'questionId': 'core_en_042', 'text': 42}),
        ),
      );

      expect(
        repository.watchAnswer('couple-1', '20260710', 'uid-1').first,
        throwsA(isA<CoupleDataUnknownException>()),
      );
    });
  });

  group('saveAnswer', () {
    test('writes exactly the rules-shaped surface: questionId, text and a '
        'server-stamped answeredAt', () async {
      when(() => answerDoc.set(any())).thenAnswer((_) async {});

      await repository.saveAnswer(
        'couple-1',
        '20260710',
        authorUid: 'uid-1',
        questionId: 'core_en_042',
        text: 'You, always.',
      );

      // Capturing the single positional arg also proves the write is a full
      // replace: no SetOptions merge was passed alongside the map.
      final captured = verify(() => answerDoc.set(captureAny())).captured;
      final data = captured.single as Map<String, Object?>;
      // The rules enforce hasOnly([questionId, text, answeredAt]) and
      // answeredAt == request.time — this write shape is the contract.
      expect(data.keys, hasLength(3));
      expect(data['questionId'], 'core_en_042');
      expect(data['text'], 'You, always.');
      expect(data['answeredAt'], isA<FieldValue>());
    });

    test('maps rules denials to permission', () {
      when(() => answerDoc.set(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(
        () => repository.saveAnswer(
          'couple-1',
          '20260710',
          authorUid: 'uid-1',
          questionId: 'q',
          text: 'Hi',
        ),
        throwsA(isA<CoupleDataPermissionException>()),
      );
    });

    test('maps a transient availability failure to network', () {
      when(() => answerDoc.set(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      expect(
        () => repository.saveAnswer(
          'couple-1',
          '20260710',
          authorUid: 'uid-1',
          questionId: 'q',
          text: 'Hi',
        ),
        throwsA(isA<CoupleDataNetworkException>()),
      );
    });
  });

  // The shared choke point for all three couple repositories lives here (the
  // answers seam is the richest — read + write); the couple and day tests
  // exercise it only through their stream paths.
  group('mapCoupleDataFailure', () {
    CoupleDataException map(String code) => mapCoupleDataFailure(
      FirebaseException(plugin: 'cloud_firestore', code: code),
    );

    test('transient availability codes become network failures', () {
      expect(map('unavailable'), isA<CoupleDataNetworkException>());
      expect(map('deadline-exceeded'), isA<CoupleDataNetworkException>());
    });

    test('rules and auth denials become permission failures', () {
      expect(map('permission-denied'), isA<CoupleDataPermissionException>());
      expect(map('unauthenticated'), isA<CoupleDataPermissionException>());
    });

    test('anything else keeps its raw code for diagnostics', () {
      final failure = map('failed-precondition');
      expect(failure, isA<CoupleDataUnknownException>());
      expect(
        (failure as CoupleDataUnknownException).code,
        'failed-precondition',
      );
    });

    test('already-mapped exceptions pass through unchanged', () {
      const mapped = CoupleDataNetworkException(message: 'off');
      expect(mapCoupleDataFailure(mapped), same(mapped));
    });

    test('non-Firebase throwables are wrapped as unknown with an '
        '"unexpected" code, never rethrown raw', () {
      final wrapped = mapCoupleDataFailure(StateError('boom'));
      expect(wrapped, isA<CoupleDataUnknownException>());
      expect((wrapped as CoupleDataUnknownException).code, 'unexpected');
      expect(
        mapCoupleDataFailure(const FormatException('bad doc')),
        isA<CoupleDataUnknownException>().having(
          (e) => e.code,
          'code',
          'unexpected',
        ),
      );
    });
  });
}
