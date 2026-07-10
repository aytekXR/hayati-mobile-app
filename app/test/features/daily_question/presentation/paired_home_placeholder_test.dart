import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/daily_question/presentation/paired_home_placeholder.dart';

import '../../../support/localized_app.dart';

void main() {
  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets('renders the paired confirmation localized ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        await tester.pumpWidget(
          localizedApp(const PairedHomePlaceholder(), locale: locale),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.pairedTitle), findsOneWidget);
        expect(find.text(l10n.pairedBody), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(PairedHomePlaceholder))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
