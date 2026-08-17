import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/notifications/data/firestore_push_diagnostic_recorder.dart';
import 'package:hayati_app/features/notifications/domain/push_diagnostic.dart';
import 'package:hayati_app/features/notifications/domain/push_registration.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

/// The thin half of ADR-049: the adapter, on the `FirestoreProfileRepository`
/// mocktail mold.
///
/// Three properties are worth a test here and nothing else is:
///
///   * **`update`, never `set`.** A `set` on a missing document CREATES it, and a
///     `users/{uid}` conjured by this path would carry no `createdAt` and no
///     `status` — a document `profileFromMap` throws on, taking the profile
///     stream and the onboarding gate with it. That is not a hypothetical: this
///     write can fire between sign-in and profile capture on a new account.
///   * **the server stamps `at`.** The rules require `at == request.time`, so a
///     client `DateTime` would be denied — and, worse, would be a forgeable
///     claim about freshness if it were not.
///   * **nothing escapes.** The seam's contract is that a failed diagnostic costs
///     the diagnostic and nothing else.
void main() {
  late MockFirebaseFirestore firestore;
  late MockCollectionReference users;
  late MockDocumentReference document;
  late List<String> failures;
  late FirestorePushDiagnosticRecorder recorder;

  setUp(() {
    firestore = MockFirebaseFirestore();
    users = MockCollectionReference();
    document = MockDocumentReference();
    failures = [];
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(any())).thenReturn(document);
    recorder = FirestorePushDiagnosticRecorder(
      firestore: firestore,
      onFailure: failures.add,
    );
  });

  Map<String, dynamic> capturedDiagnostic() {
    final written =
        verify(() => document.update(captureAny())).captured.single
            as Map<Object, Object?>;
    return written['pushDiagnostic']! as Map<String, dynamic>;
  }

  test(
    'annotates the existing document with UPDATE — never set/merge',
    () async {
      when(() => document.update(any())).thenAnswer((_) async {});

      await recorder.record(
        'uid-1',
        const PushDiagnostic(
          state: PushRegistrationState.denied,
          detail: PushDiagnosticDetail.permissionRequestRefused,
        ),
      );

      verify(() => users.doc('uid-1')).called(1);
      verifyNever(() => document.set(any()));
      verifyNever(() => document.set(any(), any()));
      final diagnostic = capturedDiagnostic();
      expect(diagnostic['state'], 'denied');
      expect(diagnostic['detail'], 'permissionRequestRefused');
    },
  );

  test(
    'lets the SERVER stamp the time — a client clock cannot forge freshness',
    () async {
      when(() => document.update(any())).thenAnswer((_) async {});

      await recorder.record(
        'uid-1',
        const PushDiagnostic(state: PushRegistrationState.registered),
      );

      expect(capturedDiagnostic()['at'], isA<FieldValue>());
    },
  );

  test(
    'omits detail entirely when there is none — never writes a null',
    () async {
      when(() => document.update(any())).thenAnswer((_) async {});

      await recorder.record(
        'uid-1',
        const PushDiagnostic(state: PushRegistrationState.registered),
      );

      // The rules accept `state`+`at` or `state`+`detail`+`at` and nothing else; a
      // literal null `detail` is a fourth shape they would deny.
      expect(capturedDiagnostic().containsKey('detail'), isFalse);
    },
  );

  test('a missing profile document is a NAMED no-op, not a throw', () async {
    when(() => document.update(any())).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
    );

    await recorder.record(
      'uid-1',
      const PushDiagnostic(state: PushRegistrationState.notDetermined),
    );

    expect(failures.single, contains('not-found'));
  });

  test(
    'a rules denial (the sign-out race) is swallowed the same way',
    () async {
      when(() => document.update(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      await recorder.record(
        'uid-1',
        const PushDiagnostic(state: PushRegistrationState.denied),
      );

      expect(failures.single, contains('permission-denied'));
    },
  );

  test(
    'a non-Firebase failure records its TYPE and never its message',
    () async {
      when(
        () => document.update(any()),
      ).thenThrow(StateError('uid-1 token abc123 leaked into a log line'));

      await recorder.record(
        'uid-1',
        const PushDiagnostic(state: PushRegistrationState.denied),
      );

      expect(failures.single, contains('StateError'));
      expect(failures.single, isNot(contains('abc123')));
    },
  );
}
