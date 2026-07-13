import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/legal/presentation/consent_gate_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_data_rights_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/golden/golden_harness.dart';

/// The special-category consent gate across the matrix (ADR-023 D3): the summary
/// paragraphs, the two document links, the severed 18+ statement, the single CTA,
/// and the three escape affordances — all in the natural first-open state.
const _uid = 'uid-1';
const _unconsented = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
);

void main() {
  List<Override> arrange() {
    final profiles = FakeProfileRepository(
      initialProfiles: const {_uid: _unconsented},
    );
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: _uid, displayName: 'Aytek'),
    );
    addTearDown(profiles.dispose);
    addTearDown(auth.dispose);
    return [
      profileRepositoryProvider.overrideWith((ref) => profiles),
      authRepositoryProvider.overrideWith((ref) => auth),
      dataRightsRepositoryProvider.overrideWith(
        (ref) => FakeDataRightsRepository(),
      ),
    ];
  }

  Future<void> pump(
    WidgetTester tester,
    GoldenCell cell, {
    double textScale = 1.0,
  }) async {
    await pumpGolden(
      tester,
      const ConsentGateScreen(uid: _uid),
      locale: cell.locale,
      direction: cell.direction,
      overrides: arrange(),
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  for (final cell in sixCells) {
    testWidgets('gate ${cell.suffix}', (tester) async {
      await pump(tester, cell);
      await expectLater(
        find.byType(ConsentGateScreen),
        matchesGoldenFile(
          goldenFile('consent_gate_screen', 'gate', cell.suffix),
        ),
      );
    });
  }

  for (final cell in naturalCells) {
    testWidgets('gate scale130 ${cell.suffix}', (tester) async {
      await pump(tester, cell, textScale: 1.3);
      await expectLater(
        find.byType(ConsentGateScreen),
        matchesGoldenFile(
          goldenFile('consent_gate_screen', 'gate.scale130', cell.suffix),
        ),
      );
    });
  }
}
