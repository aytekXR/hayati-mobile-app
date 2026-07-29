import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/bootstrap/boot_failure_app.dart';

import '../../support/localized_app.dart';

/// The screen that replaces a permanently-stuck launch image (ADR-039).
///
/// What is asserted here is not styling but the three promises the boot path
/// now makes: something is ALWAYS rendered, the user can always retry, and the
/// failure is always visible to a tester who is about to send a screenshot.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    Object failure = 'FirebaseException: no such project',
    required Future<void> Function() retry,
    Locale locale = const Locale('en'),
  }) => tester.pumpWidget(
    // The real widget builds its own MaterialApp (it must — it renders on a
    // path where the app root never booted). Wrapping it in localizedApp would
    // nest two MaterialApps, so only the inner screen is exercised through the
    // public entry the entrypoints use.
    BootFailureApp(failure: failure, retry: retry),
  );

  testWidgets('renders honest copy and a retry instead of nothing', (
    tester,
  ) async {
    final l10n = l10nFor(const Locale('en'));
    await pump(tester, retry: () async {});
    await tester.pumpAndSettle();

    expect(find.text(l10n.bootFailedTitle), findsOneWidget);
    expect(find.text(l10n.bootFailedBody), findsOneWidget);
    expect(find.text(l10n.tryAgain), findsOneWidget);
  });

  testWidgets('retry re-runs the bootstrap', (tester) async {
    final l10n = l10nFor(const Locale('en'));
    var attempts = 0;
    await pump(
      tester,
      retry: () async {
        attempts++;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.tryAgain));
    await tester.pumpAndSettle();

    expect(attempts, 1);
  });

  testWidgets('a retry in flight shows progress and drops re-entrant taps', (
    tester,
  ) async {
    final l10n = l10nFor(const Locale('en'));
    final gate = Completer<void>();
    var attempts = 0;
    await pump(
      tester,
      retry: () {
        attempts++;
        return gate.future;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.tryAgain));
    await tester.pump();

    // The label is replaced by a spinner, so a second tap cannot even find it —
    // and the guard holds regardless.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.tryAgain), findsNothing);
    expect(attempts, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.tryAgain), findsOneWidget);
  });

  testWidgets('the failure is reachable, but not shouted', (tester) async {
    final l10n = l10nFor(const Locale('en'));
    await pump(
      tester,
      failure: 'FirebaseException: channel-error',
      retry: () async {},
    );
    await tester.pumpAndSettle();

    // Collapsed by default: the screen stays calm for the user who only wants
    // the button.
    expect(find.text('FirebaseException: channel-error'), findsNothing);
    expect(find.text(l10n.bootFailedDetails), findsOneWidget);

    await tester.tap(find.text(l10n.bootFailedDetails));
    await tester.pumpAndSettle();

    // ...and diagnosable for the tester who is about to send a screenshot.
    expect(find.text('FirebaseException: channel-error'), findsOneWidget);
  });

  for (final locale in supportedTestLocales) {
    testWidgets('renders in $locale', (tester) async {
      await pump(tester, retry: () async {}, locale: locale);
      await tester.pumpAndSettle();

      // The screen builds its own MaterialApp with no `locale:` override, so it
      // follows the device. What matters per-locale is that the bundle resolves
      // and the copy carries no brand name (frontend-brandkit §1) — the brand
      // lives in core/config, which this screen deliberately does not read.
      final l10n = l10nFor(locale);
      expect(l10n.bootFailedTitle, isNotEmpty);
      expect(l10n.bootFailedBody, isNotEmpty);
      expect(l10n.bootFailedTitle.toLowerCase(), isNot(contains('ikimiz')));
      expect(l10n.bootFailedBody.toLowerCase(), isNot(contains('ikimiz')));
    });
  }
}
