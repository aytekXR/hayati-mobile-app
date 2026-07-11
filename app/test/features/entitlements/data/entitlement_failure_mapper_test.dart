import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/data/entitlement_failure_mapper.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_data_exception.dart';

void main() {
  group('mapEntitlementDataFailure', () {
    test('maps transient availability codes to network', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          mapEntitlementDataFailure(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          isA<EntitlementDataNetworkException>(),
          reason: '$code must map to network',
        );
      }
    });

    test('maps rules/auth denials to permission', () {
      for (final code in ['permission-denied', 'unauthenticated']) {
        expect(
          mapEntitlementDataFailure(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          ),
          isA<EntitlementDataPermissionException>(),
          reason: '$code must map to permission',
        );
      }
    });

    test('maps an unrecognized code to unknown, preserving the code', () {
      expect(
        mapEntitlementDataFailure(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
          ),
        ),
        isA<EntitlementDataUnknownException>().having(
          (e) => e.code,
          'code',
          'failed-precondition',
        ),
      );
    });

    test('passes an already-taxonomised failure through unchanged', () {
      const failure = EntitlementDataNetworkException(message: 'offline');
      expect(mapEntitlementDataFailure(failure), same(failure));
    });

    test('maps a non-Firebase throwable to unknown/unexpected', () {
      // A DTO FormatException (a malformed doc) crosses here as an unexpected
      // unknown — never raw, so nothing escapes the taxonomy.
      expect(
        mapEntitlementDataFailure(const FormatException('bad field')),
        isA<EntitlementDataUnknownException>().having(
          (e) => e.code,
          'code',
          'unexpected',
        ),
      );
    });
  });
}
