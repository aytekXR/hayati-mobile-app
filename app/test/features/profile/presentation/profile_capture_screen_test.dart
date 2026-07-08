import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati_app/features/profile/domain/profile_exception.dart';
import 'package:hayati_app/features/profile/domain/profile_repository_provider.dart';
import 'package:hayati_app/features/profile/domain/relationship_profile.dart';
import 'package:hayati_app/features/profile/presentation/profile_capture_screen.dart';

import '../../../support/fake_profile_repository.dart';
import '../../../support/localized_app.dart';

void main() {
  Future<FakeProfileRepository> pumpCapture(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final fake = FakeProfileRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      localizedApp(
        const ProfileCaptureScreen(uid: 'uid-1'),
        locale: locale,
        overrides: [profileRepositoryProvider.overrideWith((ref) => fake)],
      ),
    );
    return fake;
  }

  final en = l10nFor(const Locale('en'));

  group('content state', () {
    testWidgets('shows the status choices and a disabled continue until a '
        'status is picked', (tester) async {
      await pumpCapture(tester);

      expect(find.text(en.onboardingTitle), findsOneWidget);
      expect(find.text(en.statusDating), findsOneWidget);
      expect(find.text(en.statusEngaged), findsOneWidget);
      expect(find.text(en.statusMarried), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.continueAction),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text(en.statusMarried));
      await tester.pump();

      final enabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.continueAction),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('preselects the content language from the app locale', (
      tester,
    ) async {
      await pumpCapture(tester, locale: const Locale('tr'));

      final tr = l10nFor(const Locale('tr'));
      final chip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text(tr.languageTurkish),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('shows the register choice only for Turkish content', (
      tester,
    ) async {
      await pumpCapture(tester); // en locale → English preselected

      expect(find.text(en.registerLabel), findsNothing);

      await tester.tap(find.text(en.languageTurkish));
      await tester.pump();

      expect(find.text(en.registerLabel), findsOneWidget);
      expect(find.text(en.registerPlayful), findsOneWidget);
      expect(find.text(en.registerRespectful), findsOneWidget);

      await tester.tap(find.text(en.languageEnglish));
      await tester.pump();

      expect(find.text(en.registerLabel), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('a complete capture saves the profile once', (tester) async {
      final fake = await pumpCapture(tester, locale: const Locale('tr'));
      final tr = l10nFor(const Locale('tr'));

      await tester.tap(find.text(tr.statusMarried));
      await tester.pump();
      await tester.tap(find.text(tr.registerPlayful));
      await tester.pump();
      await tester.tap(find.text(tr.continueAction));
      await tester.pumpAndSettle();

      expect(fake.saveCalls, 1);
      final saved = await fake.watchProfile('uid-1').first;
      expect(
        saved,
        const RelationshipProfile(
          status: RelationshipStatus.married,
          contentLanguage: ContentLanguage.tr,
          register: ContentRegister.playful,
        ),
      );
    });

    testWidgets('non-Turkish captures default the register to respectful', (
      tester,
    ) async {
      final fake = await pumpCapture(tester);

      await tester.tap(find.text(en.statusDating));
      await tester.pump();
      await tester.tap(find.text(en.continueAction));
      await tester.pumpAndSettle();

      final saved = await fake.watchProfile('uid-1').first;
      expect(saved?.contentLanguage, ContentLanguage.en);
      expect(saved?.register, ContentRegister.respectful);
    });

    testWidgets('shows progress while the save is in flight and debounces '
        'double taps', (tester) async {
      final fake = await pumpCapture(tester);
      final gate = Completer<void>();
      fake.onSaveProfile = (_, _) => gate.future;

      await tester.tap(find.text(en.statusMarried));
      await tester.pump();
      await tester.tap(find.text(en.continueAction));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Button is disabled mid-save; a second tap must not double-submit.
      await tester.tap(find.text(en.continueAction), warnIfMissed: false);
      await tester.pump();
      expect(fake.saveCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('error state', () {
    testWidgets('a failed save surfaces mapped copy and re-enables retry', (
      tester,
    ) async {
      final fake = await pumpCapture(tester);
      fake.onSaveProfile = (_, _) async {
        throw const ProfileNetworkException(message: 'offline');
      };

      await tester.tap(find.text(en.statusEngaged));
      await tester.pump();
      await tester.tap(find.text(en.continueAction));
      await tester.pumpAndSettle();

      expect(find.text(en.profileSaveFailedTitle), findsOneWidget);
      expect(find.text(en.errorNetworkRetry), findsOneWidget);

      fake.onSaveProfile = null;
      await tester.tap(find.text(en.continueAction));
      await tester.pumpAndSettle();

      expect(fake.saveCalls, 2);
      expect(find.text(en.profileSaveFailedTitle), findsNothing);
    });
  });

  group('locale matrix', () {
    for (final locale in supportedTestLocales) {
      testWidgets('renders the full capture flow localized ($locale)', (
        tester,
      ) async {
        final l10n = l10nFor(locale);
        final fake = await pumpCapture(tester, locale: locale);

        expect(find.text(l10n.onboardingTitle), findsOneWidget);
        expect(find.text(l10n.relationshipStatusLabel), findsOneWidget);
        expect(find.text(l10n.contentLanguageLabel), findsOneWidget);

        await tester.tap(find.text(l10n.statusMarried));
        await tester.pump();
        await tester.tap(find.text(l10n.continueAction));
        await tester.pumpAndSettle();

        expect(fake.saveCalls, 1);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
