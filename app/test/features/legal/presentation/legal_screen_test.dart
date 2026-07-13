import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_exception.dart';
import 'package:hayati_app/features/data_rights/domain/data_rights_repository_provider.dart';
import 'package:hayati_app/features/legal/domain/legal_version.dart';
import 'package:hayati_app/features/legal/presentation/legal_screen.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../../support/fake_data_rights_repository.dart';
import '../../../support/fake_profile_repository.dart';
import '../../../support/localized_app.dart';

const _uid = 'uid-1';
final _dt = DateTime.utc(2026, 7, 12);
final _consented = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
  consent: Consent(version: currentLegalVersion, acceptedAt: _dt),
);
const _unconsented = RelationshipProfile(
  status: RelationshipStatus.married,
  contentLanguage: ContentLanguage.tr,
  register: ContentRegister.playful,
);

void main() {
  final en = l10nFor(const Locale('en'));

  ({
    FakeProfileRepository profiles,
    FakeDataRightsRepository dataRights,
    List<Override> overrides,
  })
  arrange({
    required RelationshipProfile profile,
    FakeDataRightsRepository? dataRights,
  }) {
    final profiles = FakeProfileRepository(initialProfiles: {_uid: profile});
    final dataRightsRepo = dataRights ?? FakeDataRightsRepository();
    addTearDown(profiles.dispose);
    return (
      profiles: profiles,
      dataRights: dataRightsRepo,
      overrides: [
        profileRepositoryProvider.overrideWith((ref) => profiles),
        dataRightsRepositoryProvider.overrideWith((ref) => dataRightsRepo),
      ],
    );
  }

  Future<void> pump(WidgetTester tester, List<Override> overrides) async {
    await tester.pumpWidget(
      localizedApp(const LegalScreen(uid: _uid), overrides: overrides),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the two document tiles', (tester) async {
    final env = arrange(profile: _consented);
    await pump(tester, env.overrides);

    expect(find.text(en.legalPrivacyTitle), findsOneWidget);
    expect(find.text(en.legalTermsTitle), findsOneWidget);
  });

  testWidgets('the consent status line renders the date and version', (
    tester,
  ) async {
    final env = arrange(profile: _consented);
    await pump(tester, env.overrides);

    expect(
      find.text(en.legalConsentStatus(_dt, currentLegalVersion)),
      findsOneWidget,
    );
  });

  testWidgets('absent consent → the status line is absent-safe and no withdraw '
      'action is offered', (tester) async {
    final env = arrange(profile: _unconsented);
    await pump(tester, env.overrides);

    expect(find.text(en.legalConsentStatusNone), findsOneWidget);
    expect(find.text(en.legalWithdrawTitle), findsNothing);
  });

  testWidgets('the withdraw confirm dialog carries the honest copy and confirm '
      'calls recordConsent(withdraw:true)', (tester) async {
    final env = arrange(profile: _consented);
    await pump(tester, env.overrides);

    await tester.tap(find.text(en.legalWithdrawTitle));
    await tester.pumpAndSettle();

    // The dialog states plainly that stored data remains and offers nothing
    // destructive itself.
    expect(find.text(en.legalWithdrawDialogTitle), findsOneWidget);
    expect(find.text(en.legalWithdrawDialogBody), findsOneWidget);
    expect(find.text(en.legalWithdrawDialogConfirm), findsOneWidget);
    expect(find.text(en.settingsCancel), findsOneWidget);

    await tester.tap(find.text(en.legalWithdrawDialogConfirm));
    await tester.pumpAndSettle();

    expect(env.dataRights.recordConsentCalls, [true]);
  });

  testWidgets('cancelling the withdraw dialog calls nothing', (tester) async {
    final env = arrange(profile: _consented);
    await pump(tester, env.overrides);

    await tester.tap(find.text(en.legalWithdrawTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.settingsCancel));
    await tester.pumpAndSettle();

    expect(env.dataRights.recordConsentCalls, isEmpty);
  });

  testWidgets('a failed withdraw shows the honest error line', (tester) async {
    final dataRights = FakeDataRightsRepository()
      ..onRecordConsent = (_) async => throw const DataRightsNetworkException();
    final env = arrange(profile: _consented, dataRights: dataRights);
    await pump(tester, env.overrides);

    await tester.tap(find.text(en.legalWithdrawTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.legalWithdrawDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.text(en.legalWithdrawError), findsOneWidget);
  });

  testWidgets('withdrawing updates the status line to none when the stream '
      'clears consent', (tester) async {
    final env = arrange(profile: _consented);
    await pump(tester, env.overrides);

    await tester.tap(find.text(en.legalWithdrawTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.legalWithdrawDialogConfirm));
    await tester.pumpAndSettle();

    env.profiles.emitProfile(_uid, _unconsented);
    await tester.pumpAndSettle();

    expect(find.text(en.legalConsentStatusNone), findsOneWidget);
    expect(find.text(en.legalWithdrawTitle), findsNothing);
  });
}
