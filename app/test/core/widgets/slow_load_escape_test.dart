import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/widgets/slow_load_escape.dart';

import '../../support/localized_app.dart';

/// The widget that stops a blocking load from becoming a dead end (ADR-039).
///
/// Both directions matter and both are asserted: BEFORE the threshold it must be
/// indistinguishable from the bare spinner it replaced — no copy, no buttons, no
/// penalty for an ordinary slow second — and AFTER it, the escape must appear
/// WITHOUT the spinner going away, because the load has not failed and the
/// widget must not claim it has.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    Duration threshold = kSlowLoadThreshold,
    Locale locale = const Locale('en'),
  }) => tester.pumpWidget(
    localizedApp(
      SlowLoadEscape(
        threshold: threshold,
        actions: [
          FilledButton(onPressed: () {}, child: const Text('retry-probe')),
        ],
      ),
      locale: locale,
    ),
  );

  testWidgets('is a bare spinner before the threshold', (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('retry-probe'), findsNothing);
    expect(
      find.text(l10nFor(const Locale('en')).loadingSlowBody),
      findsNothing,
    );
  });

  testWidgets('still a bare spinner one tick BEFORE the threshold', (
    tester,
  ) async {
    // Pins the boundary rather than just "eventually": a widget that revealed
    // early would pass the test above and still flash copy at every user.
    await pump(tester, threshold: const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 7, milliseconds: 999));

    expect(find.text('retry-probe'), findsNothing);
  });

  testWidgets('reveals the copy and the actions after the threshold', (
    tester,
  ) async {
    final l10n = l10nFor(const Locale('en'));
    await pump(tester, threshold: const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 8));

    expect(find.text(l10n.loadingSlowBody), findsOneWidget);
    expect(find.text('retry-probe'), findsOneWidget);
    // The spinner STAYS. The load is still open; removing it would assert a
    // failure that has not happened.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('settling before the threshold leaves no pending timer', (
    tester,
  ) async {
    // The failure this guards is a leaked Timer, which `flutter_test` reports as
    // "A Timer is still pending even after the widget tree was disposed" — so
    // the assertion is that this test finishes at all after the widget is
    // replaced mid-countdown.
    await pump(tester, threshold: const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(localizedApp(const SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 30));

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final locale in supportedTestLocales) {
    testWidgets('renders the escape in $locale', (tester) async {
      await pump(tester, threshold: const Duration(seconds: 8), locale: locale);
      await tester.pump(const Duration(seconds: 8));

      expect(find.text(l10nFor(locale).loadingSlowBody), findsOneWidget);
    });
  }
}
