import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/data/firestore_solo_answers_repository.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer.dart';
import 'package:hayati_app/features/daily_question/domain/solo_answer_exception.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// The @sealed markers below are advisory annotations (not class modifiers) —
// mocktail-mocking them is the established way to unit-test against
// cloud_firestore without a live app (same pattern as
// firestore_profile_repository_test.dart); the real wire path is exercised by
// the emulator rules suite.

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
  late MockCollectionReference users;
  late MockDocumentReference userDoc;
  late MockCollectionReference answers;
  late MockDocumentReference answerDoc;
  late FirestoreSoloAnswersRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    firestore = MockFirebaseFirestore();
    users = MockCollectionReference();
    userDoc = MockDocumentReference();
    answers = MockCollectionReference();
    answerDoc = MockDocumentReference();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    when(() => userDoc.collection('soloAnswers')).thenReturn(answers);
    when(() => answers.doc('20260710')).thenReturn(answerDoc);
    repository = FirestoreSoloAnswersRepository(firestore: firestore);
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
            'questionId': 'solo_en_003',
            'text': 'A quiet morning together.',
            'answeredAt': Timestamp.fromMillisecondsSinceEpoch(1783080000000),
          }),
        ),
      );

      expect(
        await repository.watchAnswer('uid-1', '20260710').first,
        SoloAnswer(
          questionId: 'solo_en_003',
          text: 'A quiet morning together.',
          answeredAt: DateTime.fromMillisecondsSinceEpoch(1783080000000),
        ),
      );
    });

    test('emits null while the day is unanswered', () async {
      when(
        answerDoc.snapshots,
      ).thenAnswer((_) => Stream.value(snapshotWith(null)));

      expect(await repository.watchAnswer('uid-1', '20260710').first, isNull);
    });

    test('a pending server stamp (local echo) crosses as a null '
        'answeredAt', () async {
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'questionId': 'solo_en_003',
            'text': 'Hi',
            'answeredAt': null,
          }),
        ),
      );

      final answer = await repository.watchAnswer('uid-1', '20260710').first;
      expect(answer?.answeredAt, isNull);
    });

    test('maps stream failures into the domain taxonomy', () {
      when(answerDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      expect(
        repository.watchAnswer('uid-1', '20260710').first,
        throwsA(isA<SoloAnswerNetworkException>()),
      );
    });

    test('maps malformed documents to SoloAnswerUnknownException', () {
      when(
        answerDoc.snapshots,
      ).thenAnswer((_) => Stream.value(snapshotWith({'text': 42})));

      expect(
        repository.watchAnswer('uid-1', '20260710').first,
        throwsA(isA<SoloAnswerUnknownException>()),
      );
    });
  });

  group('saveAnswer', () {
    test('writes exactly the rules-shaped surface: questionId, text and a '
        'server-stamped answeredAt', () async {
      when(() => answerDoc.set(any())).thenAnswer((_) async {});

      await repository.saveAnswer(
        'uid-1',
        '20260710',
        questionId: 'solo_en_003',
        text: 'A quiet morning together.',
      );

      final captured = verify(() => answerDoc.set(captureAny())).captured;
      final data = captured.single as Map<String, Object?>;
      // The rules enforce hasOnly([questionId, text, answeredAt]) and
      // answeredAt == request.time — this write shape is the contract.
      expect(data.keys, hasLength(3));
      expect(data['questionId'], 'solo_en_003');
      expect(data['text'], 'A quiet morning together.');
      expect(data['answeredAt'], isA<FieldValue>());
    });

    test('maps rules denials to SoloAnswerPermissionException', () {
      when(() => answerDoc.set(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(
        () => repository.saveAnswer(
          'uid-1',
          '20260710',
          questionId: 'q',
          text: 'Hi',
        ),
        throwsA(isA<SoloAnswerPermissionException>()),
      );
    });
  });

  group('mapSoloAnswerFailure', () {
    SoloAnswerException map(String code) => mapSoloAnswerFailure(
      FirebaseException(plugin: 'cloud_firestore', code: code),
    );

    test('transient availability codes become network failures', () {
      expect(map('unavailable'), isA<SoloAnswerNetworkException>());
      expect(map('deadline-exceeded'), isA<SoloAnswerNetworkException>());
    });

    test('rules and auth denials become permission failures', () {
      expect(map('permission-denied'), isA<SoloAnswerPermissionException>());
      expect(map('unauthenticated'), isA<SoloAnswerPermissionException>());
    });

    test('anything else keeps its raw code for diagnostics', () {
      final failure = map('failed-precondition');
      expect(failure, isA<SoloAnswerUnknownException>());
      expect(
        (failure as SoloAnswerUnknownException).code,
        'failed-precondition',
      );
    });

    test('already-mapped exceptions pass through unchanged', () {
      const mapped = SoloAnswerNetworkException(message: 'off');
      expect(mapSoloAnswerFailure(mapped), same(mapped));
    });

    test('non-Firebase throwables are wrapped, never rethrown raw', () {
      expect(
        mapSoloAnswerFailure(StateError('boom')),
        isA<SoloAnswerUnknownException>(),
      );
      expect(
        mapSoloAnswerFailure(const FormatException('bad doc')),
        isA<SoloAnswerUnknownException>(),
      );
    });
  });
}
