import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/profile/domain/profile_exception.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/presentation/onboarding_gate.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/golden/golden_harness.dart';

const _user = AuthUser(uid: 'uid-1', displayName: 'Aytek');

// The gate's loading state is deliberately NOT golden'd (a transient spinner
// with no stable frame); its fresh-signup destination is covered by the
// ProfileCaptureScreen goldens, and its existing-profile destination by the
// InvitePartnerPlaceholder goldens. Only the _GateErrorView is captured here.
void main() {
  for (final cell in sixCells) {
    testWidgets('error ${cell.suffix}', (tester) async {
      final profiles = FakeProfileRepository();
      final auth = FakeAuthRepository(initialUser: _user);
      addTearDown(profiles.dispose);
      addTearDown(auth.dispose);

      await pumpGolden(
        tester,
        const OnboardingGate(user: _user),
        locale: cell.locale,
        direction: cell.direction,
        overrides: [
          profileRepositoryProvider.overrideWith((ref) => profiles),
          authRepositoryProvider.overrideWith((ref) => auth),
        ],
      );
      // Leave the loading frame, then push a stream failure → _GateErrorView.
      await tester.pumpAndSettle();
      profiles.emitError(
        _user.uid,
        const ProfileNetworkException(message: 'off'),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(OnboardingGate),
        matchesGoldenFile(goldenFile('onboarding_gate', 'error', cell.suffix)),
      );
    });
  }
}
