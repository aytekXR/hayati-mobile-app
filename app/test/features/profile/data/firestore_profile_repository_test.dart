import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/profile/data/firestore_profile_repository.dart';
import 'package:hayati_app/features/profile/domain/profile_exception.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// The @sealed markers below are advisory annotations (not class modifiers) —
// mocktail-mocking them is the established way to unit-test against
// cloud_firestore without a live app; the real wiring is covered by
// integration_test/profile_emulator_test.dart.

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockTransaction extends Mock implements Transaction {}

const profile = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.ar,
  register: ContentRegister.respectful,
);

void main() {
  late MockFirebaseFirestore firestore;
  late MockCollectionReference users;
  late MockDocumentReference doc;
  late MockTransaction transaction;
  late FirestoreProfileRepository repository;

  Future<void> fallbackTransactionHandler(Transaction transaction) async {}

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(fallbackTransactionHandler);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    firestore = MockFirebaseFirestore();
    users = MockCollectionReference();
    doc = MockDocumentReference();
    transaction = MockTransaction();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(doc);
    repository = FirestoreProfileRepository(firestore: firestore);
  });

  MockDocumentSnapshot snapshotWith(Map<String, dynamic>? data) {
    final snapshot = MockDocumentSnapshot();
    when(snapshot.data).thenReturn(data);
    when(() => snapshot.exists).thenReturn(data != null);
    return snapshot;
  }

  void stubTransaction() {
    when(
      () => firestore.runTransaction<void>(
        any(),
        timeout: any(named: 'timeout'),
        maxAttempts: any(named: 'maxAttempts'),
      ),
    ).thenAnswer((invocation) {
      final handler =
          invocation.positionalArguments.first
              as Future<void> Function(Transaction);
      return handler(transaction);
    });
    when(
      () => transaction.set<Map<String, dynamic>>(doc, any(), any()),
    ).thenReturn(transaction);
  }

  group('watchProfile', () {
    test('maps a document into the domain entity, converting the wire '
        'createdAt Timestamp (M2.4)', () async {
      when(doc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'status': 'married',
            'contentLanguage': 'ar',
            'register': 'respectful',
            'createdAt': Timestamp.fromMillisecondsSinceEpoch(1751980000000),
          }),
        ),
      );

      expect(
        await repository.watchProfile('uid-1').first,
        RelationshipProfile(
          status: RelationshipStatus.married,
          contentLanguage: ContentLanguage.ar,
          register: ContentRegister.respectful,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1751980000000),
        ),
      );
    });

    test('a pending createdAt server stamp (local echo) crosses as '
        'null', () async {
      when(doc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'status': 'married',
            'contentLanguage': 'ar',
            'register': 'respectful',
          }),
        ),
      );

      expect(await repository.watchProfile('uid-1').first, profile);
    });

    test('emits null while the user has no profile document', () async {
      when(doc.snapshots).thenAnswer((_) => Stream.value(snapshotWith(null)));

      expect(await repository.watchProfile('uid-1').first, isNull);
    });

    test('maps stream failures into the domain taxonomy', () {
      when(doc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      expect(
        repository.watchProfile('uid-1').first,
        throwsA(isA<ProfileNetworkException>()),
      );
    });

    test('maps malformed documents to ProfileUnknownException', () {
      when(
        doc.snapshots,
      ).thenAnswer((_) => Stream.value(snapshotWith({'status': 'divorced'})));

      expect(
        repository.watchProfile('uid-1').first,
        throwsA(isA<ProfileUnknownException>()),
      );
    });
  });

  group('saveProfile', () {
    test('first save stamps createdAt with a server timestamp', () async {
      stubTransaction();
      when(
        () => transaction.get<Map<String, dynamic>>(doc),
      ).thenAnswer((_) async => snapshotWith(null));

      await repository.saveProfile('uid-1', profile);

      final captured = verify(
        () => transaction.set<Map<String, dynamic>>(
          doc,
          captureAny(),
          captureAny(),
        ),
      ).captured;
      final data = captured.first as Map<String, Object?>;
      expect(data['status'], 'married');
      expect(data['contentLanguage'], 'ar');
      expect(data['register'], 'respectful');
      expect(data['createdAt'], isA<FieldValue>());
      // merge:true is load-bearing — it is what keeps server-owned fields
      // (createdAt on re-save, coupleId/fcmTokens later) intact. A non-null
      // SetOptions is NOT enough (review W4: merge:false would ship green).
      final options = captured.last as SetOptions?;
      expect(options?.merge, isTrue);
    });

    test('re-saving never rewrites createdAt', () async {
      stubTransaction();
      when(() => transaction.get<Map<String, dynamic>>(doc)).thenAnswer(
        (_) async => snapshotWith({
          'status': 'dating',
          'contentLanguage': 'tr',
          'register': 'playful',
          'createdAt': Timestamp.fromMillisecondsSinceEpoch(1751980000000),
        }),
      );

      await repository.saveProfile('uid-1', profile);

      final captured = verify(
        () => transaction.set<Map<String, dynamic>>(
          doc,
          captureAny(),
          captureAny(),
        ),
      ).captured;
      final data = captured.first as Map<String, Object?>;
      expect(data.containsKey('createdAt'), isFalse);
      // Omitting createdAt only preserves it because the write merges.
      expect((captured.last as SetOptions?)?.merge, isTrue);
    });

    test(
      'a profile edit never writes coupleId, preserving the server value',
      () async {
        stubTransaction();
        when(() => transaction.get<Map<String, dynamic>>(doc)).thenAnswer(
          (_) async => snapshotWith({
            'status': 'dating',
            'contentLanguage': 'tr',
            'register': 'playful',
            'createdAt': Timestamp.fromMillisecondsSinceEpoch(1751980000000),
            'coupleId': 'couple-1',
          }),
        );

        // The domain object carries the server-owned coupleId (read via
        // profileFromMap, preserved through copyWith, M2.3). Saving an edit must
        // NOT emit it, and MUST merge — so the server's pairing survives even if
        // the join landed between the read and this write.
        const edited = RelationshipProfile(
          status: RelationshipStatus.married,
          contentLanguage: ContentLanguage.ar,
          register: ContentRegister.respectful,
          coupleId: 'couple-1',
        );
        await repository.saveProfile('uid-1', edited);

        final captured = verify(
          () => transaction.set<Map<String, dynamic>>(
            doc,
            captureAny(),
            captureAny(),
          ),
        ).captured;
        final data = captured.first as Map<String, Object?>;
        expect(data.containsKey('coupleId'), isFalse);
        // Omitting coupleId only preserves it because the write merges.
        expect((captured.last as SetOptions?)?.merge, isTrue);
      },
    );

    test('maps rules denials to ProfilePermissionException', () {
      when(
        () => firestore.runTransaction<void>(
          any(),
          timeout: any(named: 'timeout'),
          maxAttempts: any(named: 'maxAttempts'),
        ),
      ).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(
        () => repository.saveProfile('uid-1', profile),
        throwsA(isA<ProfilePermissionException>()),
      );
    });
  });

  group('mapFirestoreFailure', () {
    ProfileException map(String code) => mapFirestoreFailure(
      FirebaseException(plugin: 'cloud_firestore', code: code),
    );

    test('transient availability codes become network failures', () {
      expect(map('unavailable'), isA<ProfileNetworkException>());
      expect(map('deadline-exceeded'), isA<ProfileNetworkException>());
    });

    test('rules and auth denials become permission failures', () {
      expect(map('permission-denied'), isA<ProfilePermissionException>());
      expect(map('unauthenticated'), isA<ProfilePermissionException>());
    });

    test('anything else keeps its raw code for diagnostics', () {
      final failure = map('failed-precondition');
      expect(failure, isA<ProfileUnknownException>());
      expect((failure as ProfileUnknownException).code, 'failed-precondition');
    });

    test('non-Firebase throwables are wrapped, never rethrown raw', () {
      expect(
        mapFirestoreFailure(StateError('boom')),
        isA<ProfileUnknownException>(),
      );
      expect(
        mapFirestoreFailure(const FormatException('bad doc')),
        isA<ProfileUnknownException>(),
      );
    });
  });
}
