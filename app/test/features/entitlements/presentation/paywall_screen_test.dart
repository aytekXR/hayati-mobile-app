import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/daily_question/domain/solo_clock.dart';
import 'package:hayati_app/features/entitlements/domain/couple_entitlement.dart';
import 'package:hayati_app/features/entitlements/domain/entitlement_repository_provider.dart';
import 'package:hayati_app/features/entitlements/domain/purchase_exception.dart';
import 'package:hayati_app/features/entitlements/domain/purchases_repository_provider.dart';
import 'package:hayati_app/features/entitlements/presentation/paywall_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
// flutter_riverpod's curated export omits Override; riverpod_annotation
// exposes it — the seam the other tests use.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_entitlement_repository.dart';
import '../../../support/fake_purchases_repository.dart';
import '../../../support/localized_app.dart';
import '../../../support/purchases_fixtures.dart';

const _coupleId = 'couple-1';
const _user = AuthUser(uid: 'uid-1', displayName: 'Aytek');
final _now = DateTime.utc(2026, 7, 11, 12);

/// An entitled, unexpired mirror against the pinned clock.
CoupleEntitlement _entitledMirror() => CoupleEntitlement(
  entitled: true,
  expiresAt: _now.add(const Duration(days: 30)),
);

void main() {
  final en = l10nFor(const Locale('en'));

  ({
    List<Override> overrides,
    FakePurchasesRepository purchases,
    FakeEntitlementRepository mirrors,
    FakeAuthRepository auth,
  })
  arrange({
    FakePurchasesRepository? purchases,
    FakeEntitlementRepository? mirrors,
    FakeAuthRepository? auth,
  }) {
    final p = purchases ?? FakePurchasesRepository();
    final m = mirrors ?? FakeEntitlementRepository();
    final a = auth ?? FakeAuthRepository(initialUser: _user);
    addTearDown(m.dispose);
    addTearDown(a.dispose);
    return (
      overrides: [
        purchasesRepositoryProvider.overrideWith((ref) => p),
        entitlementRepositoryProvider.overrideWith((ref) => m),
        authRepositoryProvider.overrideWith((ref) => a),
        soloClockProvider.overrideWith(
          (ref) =>
              () => _now,
        ),
      ],
      purchases: p,
      mirrors: m,
      auth: a,
    );
  }

  Future<void> pumpPaywall(WidgetTester tester, List<Override> overrides) {
    return tester.pumpWidget(
      localizedApp(
        const PaywallScreen(coupleId: _coupleId),
        overrides: overrides,
      ),
    );
  }

  group('offerings states', () {
    testWidgets('shows a spinner while offerings load', (tester) async {
      final env = arrange(
        purchases: FakePurchasesRepository()
          ..onFetchOfferings = () => Completer<Offerings>().future,
      );
      await pumpPaywall(tester, env.overrides);
      await tester.pump(); // the offerings future never completes

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'a network failure shows retry copy, and the retry re-fetches',
      (tester) async {
        var calls = 0;
        final env = arrange(
          purchases: FakePurchasesRepository()
            ..onFetchOfferings = () async {
              calls++;
              if (calls == 1) throw const PurchaseNetworkException();
              return aMockedOfferings();
            },
        );
        await pumpPaywall(tester, env.overrides);
        await tester.pumpAndSettle();

        expect(find.text(en.errorNetworkRetry), findsOneWidget);
        expect(find.text(en.tryAgain), findsOneWidget);

        await tester.tap(find.text(en.tryAgain));
        await tester.pumpAndSettle();

        // The re-fetch succeeds → loaded, the verbatim price rendered.
        expect(find.text('₺899,99'), findsOneWidget);
        expect(find.text(en.errorNetworkRetry), findsNothing);
      },
    );

    testWidgets('an unavailable failure shows the distinct store copy', (
      tester,
    ) async {
      final env = arrange(
        purchases: FakePurchasesRepository()
          ..onFetchOfferings = () async =>
              throw const PaywallUnavailableException(),
      );
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      expect(find.text(en.paywallUnavailable), findsOneWidget);
      // Distinct from the network copy.
      expect(find.text(en.errorNetworkRetry), findsNothing);
    });
  });

  group('loaded', () {
    testWidgets(
      'renders annual-first cards, badge, trial, verbatim prices, and '
      'the per-month sub-label',
      (tester) async {
        final env = arrange();
        await pumpPaywall(tester, env.overrides);
        await tester.pumpAndSettle();

        final annualPrice = find.text('₺899,99');
        final monthlyPrice = find.text('₺89,99');
        expect(annualPrice, findsOneWidget);
        expect(monthlyPrice, findsOneWidget);
        // Annual first in visual order.
        expect(
          tester.getCenter(annualPrice).dy,
          lessThan(tester.getCenter(monthlyPrice).dy),
        );
        expect(find.text(en.paywallBestValue), findsOneWidget);
        // Trial banner from the store's 7-day introductory offer.
        expect(find.text(en.paywallTrialDays(7)), findsOneWidget);
        // Store-computed per-month sub-label, verbatim price.
        expect(find.text(en.paywallApproxPerMonth('₺74,99')), findsOneWidget);
        expect(find.text(en.paywallPitch), findsOneWidget);
        expect(find.text(en.paywallFreeNote), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, en.paywallRestore),
          findsOneWidget,
        );
        // The selected (annual) package carries a trial → the trial CTA.
        expect(
          find.widgetWithText(FilledButton, en.paywallCtaTrial),
          findsOneWidget,
        );
      },
    );

    testWidgets('the trial banner localizes across the matrix', (tester) async {
      for (final locale in supportedTestLocales) {
        final env = arrange();
        await tester.pumpWidget(
          localizedApp(
            const PaywallScreen(coupleId: _coupleId),
            locale: locale,
            overrides: env.overrides,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10nFor(locale).paywallTrialDays(7)),
          findsOneWidget,
          reason: 'trial copy for $locale',
        );
      }
    });
  });

  group('entitled', () {
    testWidgets('shows confirmation + restore + manage hint, and NO buy CTA', (
      tester,
    ) async {
      final env = arrange(
        mirrors: FakeEntitlementRepository(
          initialMirrors: {_coupleId: _entitledMirror()},
        ),
      );
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      expect(find.text(en.paywallEntitledTitle), findsOneWidget);
      expect(find.text(en.paywallEntitledBody), findsOneWidget);
      expect(find.text(en.paywallManageHint), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, en.paywallRestore),
        findsOneWidget,
      );
      // No buy buttons at all.
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('purchase flow', () {
    testWidgets('a completed purchase shows the processing banner while the '
        'mirror is still free (the mirror is the only unlocker)', (
      tester,
    ) async {
      final env = arrange();
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, en.paywallCtaTrial));
      await tester.pumpAndSettle();

      expect(env.purchases.callLog, contains('purchase:rc_annual'));
      expect(find.text(en.paywallProcessing), findsOneWidget);
      // Still free → the cards remain (buy buttons not resurrected away).
      expect(find.text('₺899,99'), findsOneWidget);
    });

    testWidgets('flipping the entitlement mirror swaps to the entitled view — '
        'the ONLY unlocker', (tester) async {
      final env = arrange();
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, en.paywallCtaTrial));
      await tester.pumpAndSettle();
      expect(find.text(en.paywallProcessing), findsOneWidget);

      // The webhook writes the mirror → isPremium flips → entitled view.
      env.mirrors.emit(_coupleId, _entitledMirror());
      await tester.pumpAndSettle();

      expect(find.text(en.paywallEntitledBody), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(en.paywallProcessing), findsNothing);
    });

    testWidgets('a cancelled sheet returns to idle: no error, no banner', (
      tester,
    ) async {
      final env = arrange(
        purchases: FakePurchasesRepository()
          ..onPurchase = (_) async => throw const PurchaseCancelledException(),
      );
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, en.paywallCtaTrial));
      await tester.pumpAndSettle();

      expect(find.text(en.paywallProcessing), findsNothing);
      expect(find.text(en.errorGeneric), findsNothing);
      expect(find.text(en.errorNetworkRetry), findsNothing);
      // Still on the loaded view with the CTA.
      expect(
        find.widgetWithText(FilledButton, en.paywallCtaTrial),
        findsOneWidget,
      );
    });

    testWidgets('a store failure surfaces a dismissable error', (tester) async {
      final env = arrange(
        purchases: FakePurchasesRepository()
          ..onPurchase = (_) async => throw const PurchaseStoreException(),
      );
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, en.paywallCtaTrial));
      await tester.pumpAndSettle();
      expect(find.text(en.errorGeneric), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text(en.errorGeneric), findsNothing);
    });

    testWidgets('re-entrant CTA taps are dropped: exactly one purchase call', (
      tester,
    ) async {
      final gate = Completer<CustomerInfo>();
      final env = arrange(
        purchases: FakePurchasesRepository()..onPurchase = (_) => gate.future,
      );
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      final cta = find.widgetWithText(FilledButton, en.paywallCtaTrial);
      // Two taps against the not-yet-rebuilt tree: the controller drops the
      // second while the first is in flight, and the UI mirrors it (disabled).
      await tester.tap(cta);
      await tester.tap(cta, warnIfMissed: false);
      await tester.pump();

      gate.complete(aCustomerInfo());
      await tester.pumpAndSettle();

      expect(
        env.purchases.callLog.where((c) => c.startsWith('purchase')).length,
        1,
      );
    });

    testWidgets('restore defers to the mirror with syncing feedback', (
      tester,
    ) async {
      final env = arrange();
      await pumpPaywall(tester, env.overrides);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, en.paywallRestore));
      await tester.pumpAndSettle();

      expect(env.purchases.callLog, contains('restore'));
      expect(find.text(en.paywallRestoreProcessing), findsOneWidget);
    });
  });

  group('auth-loss self-pop', () {
    testWidgets('a remote sign-out pops the pushed paywall', (tester) async {
      final auth = FakeAuthRepository(initialUser: _user);
      final env = arrange(auth: auth);
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showPaywall(context, coupleId: _coupleId),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: env.overrides,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      auth.emit(null);
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);
    });
  });
}
