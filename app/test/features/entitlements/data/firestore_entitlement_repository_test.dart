import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/data/firestore_entitlement_repository.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_data_exception.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// The @sealed markers below are advisory annotations (not class modifiers) —
// mocktail-mocking them is the established way to unit-test against
// cloud_firestore without a live app (same pattern as
// firestore_couple_repository_test.dart); the real wire path is exercised by
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
  late MockCollectionReference subscriptions;
  late MockDocumentReference subscriptionDoc;
  late FirestoreEntitlementRepository repository;

  setUp(() {
    firestore = MockFirebaseFirestore();
    subscriptions = MockCollectionReference();
    subscriptionDoc = MockDocumentReference();
    when(() => firestore.collection('subscriptions')).thenReturn(subscriptions);
    when(() => subscriptions.doc('couple-1')).thenReturn(subscriptionDoc);
    repository = FirestoreEntitlementRepository(firestore: firestore);
  });

  MockDocumentSnapshot snapshotWith(Map<String, dynamic>? data) {
    final snapshot = MockDocumentSnapshot();
    when(snapshot.data).thenReturn(data);
    when(() => snapshot.exists).thenReturn(data != null);
    return snapshot;
  }

  group('watchEntitlement', () {
    test('maps a document into the domain summary', () async {
      when(subscriptionDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({
            'entitled': true,
            'productId': 'premium_monthly',
            'periodType': 'NORMAL',
            'expiresAtMs': 1785500400000,
            'willRenew': true,
            'store': 'APP_STORE',
            'environment': 'PRODUCTION',
          }),
        ),
      );

      expect(
        await repository.watchEntitlement('couple-1').first,
        CoupleEntitlement(
          entitled: true,
          productId: 'premium_monthly',
          periodType: 'NORMAL',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            1785500400000,
            isUtc: true,
          ),
          willRenew: true,
          store: 'APP_STORE',
          environment: 'PRODUCTION',
        ),
      );
    });

    test('emits null while the subscription doc is absent (the free tier)', () {
      when(
        subscriptionDoc.snapshots,
      ).thenAnswer((_) => Stream.value(snapshotWith(null)));

      expect(repository.watchEntitlement('couple-1').first, completion(isNull));
    });

    test('maps a transient availability failure to network', () {
      when(subscriptionDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );

      expect(
        repository.watchEntitlement('couple-1').first,
        throwsA(isA<EntitlementDataNetworkException>()),
      );
    });

    test('maps a rules denial to permission', () {
      when(subscriptionDoc.snapshots).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      );

      expect(
        repository.watchEntitlement('couple-1').first,
        throwsA(isA<EntitlementDataPermissionException>()),
      );
    });

    test('a malformed document surfaces the mapper FormatException through '
        'the taxonomy', () {
      // A non-int expiresAtMs makes coupleEntitlementFromMap throw; the
      // repository's catch routes it through mapEntitlementDataFailure, so a
      // non-Firebase throwable crosses as EntitlementDataUnknownException.
      when(subscriptionDoc.snapshots).thenAnswer(
        (_) => Stream.value(
          snapshotWith({'entitled': true, 'expiresAtMs': 'soon'}),
        ),
      );

      expect(
        repository.watchEntitlement('couple-1').first,
        throwsA(isA<EntitlementDataUnknownException>()),
      );
    });
  });
}
