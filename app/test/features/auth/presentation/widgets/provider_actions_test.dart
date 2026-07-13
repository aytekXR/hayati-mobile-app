import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/presentation/widgets/provider_actions.dart';

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/localized_app.dart';

/// The legal footer rides `ProviderActions` itself (ADR-023 D2), so every
/// surface that renders the sign-in buttons — `_SignedOutView`, the sign-in
/// `_ErrorView`, and `PartnerPreviewScreen`'s join card — carries the notice BY
/// CONSTRUCTION. Testing the one widget proves the footer for all three.
void main() {
  final en = l10nFor(const Locale('en'));

  Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en')}) {
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    return tester.pumpWidget(
      localizedApp(
        const Scaffold(body: Center(child: ProviderActions())),
        locale: locale,
        overrides: [authRepositoryProvider.overrideWith((ref) => auth)],
      ),
    );
  }

  testWidgets('renders the legal footer line and both document links', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(en.legalFooterLine), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, en.legalLinkPrivacy),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, en.legalLinkTerms), findsOneWidget);
  });

  testWidgets('the footer localizes across the matrix', (tester) async {
    for (final locale in supportedTestLocales) {
      await pump(tester, locale: locale);
      await tester.pumpAndSettle();
      expect(
        find.text(l10nFor(locale).legalFooterLine),
        findsOneWidget,
        reason: 'legal footer for $locale',
      );
    }
  });
}
