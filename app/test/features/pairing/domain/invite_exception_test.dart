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
        InviteJoinUnknownCodeException(),
        InviteJoinExpiredException(),
        InviteJoinConsumedException(),
        InviteJoinSelfJoinException(),
        InviteJoinAlreadyPairedException(),
        InviteJoinProfileMissingException(),
      ];
      for (final failure in failures) {
        final label = switch (failure) {
          InviteNetworkException() => 'network',
          InvitePermissionException() => 'permission',
          InviteUnknownException() => 'unknown',
          InviteJoinUnknownCodeException() => 'join-unknown-code',
          InviteJoinExpiredException() => 'join-expired',
          InviteJoinConsumedException() => 'join-consumed',
          InviteJoinSelfJoinException() => 'join-self',
          InviteJoinAlreadyPairedException() => 'join-already-paired',
          InviteJoinProfileMissingException() => 'join-profile-missing',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  group('join failure members', () {
    test('each member is value-equal on its message', () {
      expect(
        const InviteJoinExpiredException(message: 'gone'),
        const InviteJoinExpiredException(message: 'gone'),
      );
      expect(
        const InviteJoinExpiredException(message: 'gone'),
        isNot(const InviteJoinExpiredException(message: 'other')),
      );
      expect(
        const InviteJoinConsumedException(message: 'used'),
        const InviteJoinConsumedException(message: 'used'),
      );
    });

    test(
      'distinct members never compare equal, even with the same message',
      () {
        expect(
          const InviteJoinExpiredException(message: 'x'),
          isNot(const InviteJoinConsumedException(message: 'x')),
        );
        expect(
          const InviteJoinSelfJoinException(message: 'x'),
          isNot(const InviteJoinAlreadyPairedException(message: 'x')),
        );
      },
    );

    test('toString names the member for diagnostics', () {
      expect(
        const InviteJoinUnknownCodeException(message: 'nope').toString(),
        contains('InviteJoinUnknownCodeException'),
      );
      expect(
        const InviteJoinProfileMissingException().toString(),
        contains('InviteJoinProfileMissingException'),
      );
    });
  });
}
