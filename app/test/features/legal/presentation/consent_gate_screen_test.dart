import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/core/storage/pin_lock_store.dart';
import 'package:hayati_app/features/auth/domain/auth_repository_provider.dart';
import 'package:hayati_app/features/auth/domain/auth_user.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_exception.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/data_rights/presentation/delete_account_screen.dart';
import 'package:hayati_app/features/data_rights/presentation/export_screen.dart';
import 'package:hayati_app/features/legal/domain/consent_status.dart';
import 'package:hayati_app/features/legal/domain/legal_version.dart';
import 'package:hayati_app/features/legal/presentation/consent_gate_screen.dart';
import 'package:hayati_app/features/privacy_lock/domain/biometric_authenticator.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/state/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_data_rights_repository.dart';
import '../../../support/fake_pin_lock_store.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/localized_app.dart';

const _uid = 'uid-1';
const _unconsented = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
);
const _consented = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
  consent: Consent(version: currentLegalVersion),
);
// A grant the server stamped BELOW the app's expectation — the stale case.
const _staleConsented = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
  consent: Consent(version: currentLegalVersion - 1),
);

/// A minimal host mirroring the `OnboardingGate` consent decision so the gate's
/// clear (routes to HOME) and stale (still shows the gate) transitions are
/// observable without wiring the full gate seam set.
class _GateHost extends ConsumerWidget {
  const _GateHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileStreamProvider(_uid));
    return switch (profile) {
      AsyncData(:final value) when value != null && hasCurrentConsent(value) =>
        const Scaffold(body: Center(child: Text('HOME'))),
      AsyncData(:final value) when value != null => const ConsentGateScreen(
        uid: _uid,
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

void main() {
  final en = l10nFor(const Locale('en'));

  ({
    FakeProfileRepository profiles,
    FakeAuthRepository auth,
    FakeDataRightsRepository dataRights,
    List<Override> overrides,
  })
  arrange({
    RelationshipProfile profile = _unconsented,
    FakeDataRightsRepository? dataRights,
  }) {
    final profiles = FakeProfileRepository(initialProfiles: {_uid: profile});
    final auth = FakeAuthRepository(
      initialUser: const AuthUser(uid: _uid, displayName: 'Aytek'),
    );
    final dataRightsRepo = dataRights ?? FakeDataRightsRepository();
    addTearDown(profiles.dispose);
    addTearDown(auth.dispose);
    return (
      profiles: profiles,
      auth: auth,
      dataRights: dataRightsRepo,
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profiles),
        authRepositoryProvider.overrideWith((ref) => auth),
        dataRightsRepositoryProvider.overrideWith((ref) => dataRightsRepo),
        // Seams the escape destinations (ExportScreen / DeleteAccountScreen) read.
        pinLockStoreProvider.overrideWithValue(FakePinLockStore(initial: null)),
        initialLockSnapshotProvider.overrideWithValue(
          const PinLockSnapshot(record: null),
        ),
        biometricAuthenticatorProvider.overrideWithValue(
          FakeBiometricAuthenticator(available: false),
        ),
      ],
    );
  }

  Future<void> pump(
    WidgetTester tester,
    List<Override> overrides, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      localizedApp(const _GateHost(), locale: locale, overrides: overrides),
    );
    await tester.pumpAndSettle();
  }

  // The gate is a long scroll view; a button below the fold must be scrolled
  // into view before it is hit-testable.
  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  testWidgets('the gate renders the CTA and the three escape affordances', (
    tester,
  ) async {
    final env = arrange();
    await pump(tester, env.overrides);

    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(find.text(en.consentCta), findsOneWidget);
    expect(find.text(en.settingsSignOut), findsOneWidget);
    expect(find.text(en.dataRightsExportRowTitle), findsOneWidget);
    expect(find.text(en.dataRightsDeleteRowTitle), findsOneWidget);
    // The eligibility statement is present but severed from the CTA sentence.
    expect(find.text(en.consentAgeStatement), findsOneWidget);
  });

  testWidgets(
    'accept → recordConsent(withdraw:false); the gate clears when the '
    'streamed profile delivers consent',
    (tester) async {
      final env = arrange();
      await pump(tester, env.overrides);

      await tapText(tester, en.consentCta);
      // The CTA flips to a persistent confirming spinner, so pump frames (never
      // pumpAndSettle, which a spinner wedges) to flush the grant microtask.
      await tester.pump();
      await tester.pump();

      expect(env.dataRights.recordConsentCalls, [false]);
      // No optimistic grant — still on the gate until the server field arrives.
      expect(find.text('HOME'), findsNothing);

      env.profiles.emitProfile(_uid, _consented);
      await tester.pumpAndSettle();

      expect(find.byType(ConsentGateScreen), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('a failed grant shows the honest error and keeps the retryable '
      'CTA', (tester) async {
    final dataRights = FakeDataRightsRepository()
      ..onRecordConsent = (_) async => throw const DataRightsNetworkException();
    final env = arrange(dataRights: dataRights);
    await pump(tester, env.overrides);

    await tapText(tester, en.consentCta);
    await tester.pumpAndSettle();

    expect(find.text(en.consentError), findsOneWidget);
    // The CTA is still offered (retry), never the persistent stale line.
    expect(find.text(en.consentCta), findsOneWidget);
    expect(find.text(en.consentStaleError), findsNothing);
  });

  testWidgets('stale-after-accept: the grant succeeds but the streamed version '
      'stays below the app const → persistent error, no CTA loop', (
    tester,
  ) async {
    final env = arrange();
    await pump(tester, env.overrides);

    await tapText(tester, en.consentCta);
    // Confirming spinner up — pump frames, don't settle.
    await tester.pump();
    await tester.pump();
    expect(env.dataRights.recordConsentCalls, [false]);

    // The server stamped a version the app does not accept.
    env.profiles.emitProfile(_uid, _staleConsented);
    // The stale branch replaces the spinner with a static error line, so once
    // it lands the tree settles again.
    await tester.pumpAndSettle();

    expect(find.text(en.consentStaleError), findsOneWidget);
    expect(find.text(en.consentCta), findsNothing);
  });

  testWidgets('sign out routes through the auth controller', (tester) async {
    final env = arrange();
    await pump(tester, env.overrides);

    await tapText(tester, en.settingsSignOut);
    await tester.pumpAndSettle();

    expect(env.auth.signOutCalls, 1);
  });

  testWidgets('Download my data pushes the export screen', (tester) async {
    final env = arrange();
    await pump(tester, env.overrides);

    await tapText(tester, en.dataRightsExportRowTitle);
    await tester.pumpAndSettle();

    expect(find.byType(ExportScreen), findsOneWidget);
  });

  testWidgets('Delete account & data pushes the delete screen', (tester) async {
    final env = arrange();
    await pump(tester, env.overrides);

    await tapText(tester, en.dataRightsDeleteRowTitle);
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });
}
