import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_data_exception.dart';

void main() {
  group('EntitlementDataException taxonomy', () {
    test('network failures are value-equal', () {
      expect(
        const EntitlementDataNetworkException(message: 'offline'),
        const EntitlementDataNetworkException(message: 'offline'),
      );
      expect(
        const EntitlementDataNetworkException(message: 'offline'),
        isNot(const EntitlementDataNetworkException(message: 'timeout')),
      );
    });

    test('permission failures are value-equal', () {
      expect(
        const EntitlementDataPermissionException(message: 'denied'),
        const EntitlementDataPermissionException(message: 'denied'),
      );
    });

    test('unknown failures carry the raw code for diagnostics', () {
      const failure = EntitlementDataUnknownException(
        code: 'aborted',
        message: 'x',
      );
      expect(
        failure,
        const EntitlementDataUnknownException(code: 'aborted', message: 'x'),
      );
      expect(failure.code, 'aborted');
      expect(failure.toString(), contains('aborted'));
    });

    test('distinct subtypes with the same message are never equal', () {
      // runtimeType is part of identity, so a network and a permission failure
      // carrying the same message must not collide.
      expect(
        const EntitlementDataNetworkException(message: 'x'),
        isNot(const EntitlementDataPermissionException(message: 'x')),
      );
    });

    test('the taxonomy is exhaustive for a switch', () {
      const failures = <EntitlementDataException>[
        EntitlementDataNetworkException(),
        EntitlementDataPermissionException(),
        EntitlementDataUnknownException(),
      ];
      for (final failure in failures) {
        final label = switch (failure) {
          EntitlementDataNetworkException() => 'network',
          EntitlementDataPermissionException() => 'permission',
          EntitlementDataUnknownException() => 'unknown',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
