import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/profile/presentation/invite_partner_placeholder.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/golden/golden_harness.dart';

// A single static state — the placeholder has no loading/error variants (the
// sign-out affordance only acts inside its onPressed callback), so the auth
// override just keeps a stray tap safe during render.
void main() {
  for (final cell in sixCells) {
    testWidgets('default ${cell.suffix}', (tester) async {
      final fake = FakeAuthRepository();
      addTearDown(fake.dispose);

      await pumpGolden(
        tester,
        const InvitePartnerPlaceholder(),
        locale: cell.locale,
        direction: cell.direction,
        overrides: [authRepositoryProvider.overrideWith((ref) => fake)],
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(InvitePartnerPlaceholder),
        matchesGoldenFile(
          goldenFile('invite_partner_placeholder', 'default', cell.suffix),
        ),
      );
    });
  }
}
