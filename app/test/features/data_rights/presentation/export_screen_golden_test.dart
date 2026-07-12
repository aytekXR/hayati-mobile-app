import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/data_rights/presentation/export_screen.dart';

import '../../../support/fake_data_rights_repository.dart';
import '../../../support/golden/golden_harness.dart';

/// The export screen renders DATA, not prose, so a single natural cell suffices
/// (ADR-019 D5 — the content is a versioned JSON document, deterministic via the
/// canned export fixture).
void main() {
  testWidgets('loaded en.ltr', (tester) async {
    await pumpGolden(
      tester,
      const ExportScreen(),
      locale: const Locale('en'),
      direction: TextDirection.ltr,
      overrides: [
        dataRightsRepositoryProvider.overrideWith(
          (ref) => FakeDataRightsRepository(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ExportScreen),
      matchesGoldenFile(goldenFile('export_screen', 'loaded', 'en.ltr')),
    );
  });
}
