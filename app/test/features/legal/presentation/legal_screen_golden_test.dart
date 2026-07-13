import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/legal/domain/legal_version.dart';
import 'package:hayati_app/features/legal/presentation/legal_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_data_rights_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/golden/golden_harness.dart';

/// The Settings-reached legal hub across the matrix (ADR-023 D5): the two
/// document tiles, the dated consent status line, and the Withdraw action — the
/// ONE surface carrying consent controls.
const _uid = 'uid-1';
final _consented = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
  consent: Consent(
    version: currentLegalVersion,
    acceptedAt: DateTime.utc(2026, 7, 12),
  ),
);

void main() {
  List<Override> arrange() {
    final profiles = FakeProfileRepository(initialProfiles: {_uid: _consented});
    addTearDown(profiles.dispose);
    return [
      profileRepositoryProvider.overrideWith((ref) => profiles),
      dataRightsRepositoryProvider.overrideWith(
        (ref) => FakeDataRightsRepository(),
      ),
    ];
  }

  for (final cell in sixCells) {
    testWidgets('hub ${cell.suffix}', (tester) async {
      await pumpGolden(
        tester,
        const LegalScreen(uid: _uid),
        locale: cell.locale,
        direction: cell.direction,
        overrides: arrange(),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LegalScreen),
        matchesGoldenFile(goldenFile('legal_screen', 'hub', cell.suffix)),
      );
    });
  }
}
