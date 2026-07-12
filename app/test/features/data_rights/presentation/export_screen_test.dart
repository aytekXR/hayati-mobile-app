import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/domain/data_export.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_exception.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/data_rights/presentation/export_screen.dart';

import '../../../support/fake_data_rights_repository.dart';
import '../../../support/localized_app.dart';

void main() {
  final en = l10nFor(const Locale('en'));

  Future<void> pumpExport(
    WidgetTester tester,
    FakeDataRightsRepository dataRights,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        const ExportScreen(),
        overrides: [
          dataRightsRepositoryProvider.overrideWith((ref) => dataRights),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads and renders the JSON document with the honest intro', (
    tester,
  ) async {
    await pumpExport(tester, FakeDataRightsRepository());
    expect(find.text(en.dataRightsExportIntro), findsOneWidget);
    // The document is rendered as-is; its note (by-id, not text) is visible.
    expect(find.textContaining('formatVersion'), findsOneWidget);
    expect(find.textContaining('questionId only'), findsOneWidget);
  });

  testWidgets('the copy action writes the full pretty JSON to the clipboard '
      'and confirms', (tester) async {
    final clipboardWrites = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardWrites.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpExport(tester, FakeDataRightsRepository());
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    expect(clipboardWrites, [
      FakeDataRightsRepository.cannedExport.toPrettyJson(),
    ]);
    expect(find.text(en.dataRightsExportCopied), findsOneWidget);
  });

  testWidgets('an error shows the honest retry, and retrying re-fetches', (
    tester,
  ) async {
    var attempt = 0;
    final dataRights = FakeDataRightsRepository()
      ..onExportData = () async {
        attempt++;
        if (attempt == 1) throw const DataRightsNetworkException();
        return FakeDataRightsRepository.cannedExport;
      };

    await pumpExport(tester, dataRights);
    expect(find.text(en.dataRightsExportError), findsOneWidget);
    // No document, no copy action while errored.
    expect(find.byIcon(Icons.copy_outlined), findsNothing);

    await tester.tap(find.text(en.tryAgain));
    await tester.pumpAndSettle();

    expect(find.text(en.dataRightsExportIntro), findsOneWidget);
    expect(find.textContaining('formatVersion'), findsOneWidget);
  });

  testWidgets('a malformed body still surfaces the honest error (never a '
      'half-built document)', (tester) async {
    final dataRights = FakeDataRightsRepository()
      ..onExportData = () async =>
          throw const DataRightsUnknownException(code: 'malformed-response');
    await pumpExport(tester, dataRights);
    expect(find.text(en.dataRightsExportError), findsOneWidget);
  });

  // A tiny local sanity net that the canned export pretty-prints (used above).
  test('canned export pretty JSON is non-empty', () {
    expect(FakeDataRightsRepository.cannedExport, isA<DataExport>());
    expect(
      FakeDataRightsRepository.cannedExport.toPrettyJson(),
      contains('formatVersion'),
    );
  });
}
