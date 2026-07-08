import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/profile/domain/profile_exception.dart';

void main() {
  group('ProfileException taxonomy', () {
    test('network failures are value-equal', () {
      expect(
        const ProfileNetworkException(message: 'offline'),
        const ProfileNetworkException(message: 'offline'),
      );
      expect(
        const ProfileNetworkException(message: 'offline'),
        isNot(const ProfileNetworkException(message: 'timeout')),
      );
    });

    test('permission failures are value-equal', () {
      expect(
        const ProfilePermissionException(message: 'denied'),
        const ProfilePermissionException(message: 'denied'),
      );
    });

    test('unknown failures carry the raw code for diagnostics', () {
      const failure = ProfileUnknownException(code: 'aborted', message: 'x');
      expect(
        failure,
        const ProfileUnknownException(code: 'aborted', message: 'x'),
      );
      expect(failure.code, 'aborted');
      expect(failure.toString(), contains('aborted'));
    });

    test('the taxonomy is exhaustive for a UI switch', () {
      const failures = <ProfileException>[
        ProfileNetworkException(),
        ProfilePermissionException(),
        ProfileUnknownException(),
      ];
      for (final failure in failures) {
        final label = switch (failure) {
          ProfileNetworkException() => 'network',
          ProfilePermissionException() => 'permission',
          ProfileUnknownException() => 'unknown',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
