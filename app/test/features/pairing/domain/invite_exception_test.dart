import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/pairing/domain/invite_exception.dart';

void main() {
  group('InviteException taxonomy', () {
    test('network failures are value-equal', () {
      expect(
        const InviteNetworkException(message: 'offline'),
        const InviteNetworkException(message: 'offline'),
      );
      expect(
        const InviteNetworkException(message: 'offline'),
        isNot(const InviteNetworkException(message: 'timeout')),
      );
    });

    test('permission failures are value-equal', () {
      expect(
        const InvitePermissionException(message: 'no session'),
        const InvitePermissionException(message: 'no session'),
      );
    });

    test('unknown failures carry the raw code for diagnostics', () {
      const failure = InviteUnknownException(
        code: 'resource-exhausted',
        message: 'x',
      );
      expect(
        failure,
        const InviteUnknownException(code: 'resource-exhausted', message: 'x'),
      );
      expect(failure.code, 'resource-exhausted');
      expect(failure.toString(), contains('resource-exhausted'));
    });

    test('the taxonomy is exhaustive for a UI switch', () {
      const failures = <InviteException>[
        InviteNetworkException(),
        InvitePermissionException(),
        InviteUnknownException(),
      ];
      for (final failure in failures) {
        final label = switch (failure) {
          InviteNetworkException() => 'network',
          InvitePermissionException() => 'permission',
          InviteUnknownException() => 'unknown',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
